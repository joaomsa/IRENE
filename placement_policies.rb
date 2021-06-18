require('json')
require_relative('components')
require_relative('auxiliar_methods')
require_relative('genetic_algorithm')
require_relative('simul_annealing')

VERBOSITY = 2
SCENARIO = ARGV[1] # Example: insert 'scenario1' to use the 'datasets/dataset_scenario1.json' file

def first_fit()
	Application.all().each do |application|
		application.microservices.each do |microservice|

			Server.all().each do |server|
				if (server.free_cpu >= microservice.cpu and server.free_ram >= microservice.ram and server.free_disk >= microservice.disk)
					server.add_microservice(microservice)
					break
				end
			end

		end
	end

	placement = []
	Microservice.all().each { |microservice| placement.push(microservice.server.id) }
	return(placement)
end

def best_fit()
	Application.all().each do |application|
		application.microservices.each do |microservice|
			best_candidate = nil
			best_candidate_score = 0
			Server.all().each do |server|
				if (server.free_cpu >= microservice.cpu and server.free_ram >= microservice.ram and server.free_disk >= microservice.disk)
					score = 1 - ((server.free_cpu * server.free_ram * server.free_disk) ** (1.0/3))

					if (score > best_candidate_score or !best_candidate)
						best_candidate = server
						best_candidate_score = score
					end
				end

			end
			best_candidate.add_microservice(microservice) if (best_candidate)
		end
	end

	placement = []
	Microservice.all().each { |microservice| placement.push(microservice.server.id) }

	return(placement)
end

def worst_fit()
	Application.all().each do |application|
		application.microservices.each do |microservice|
			best_candidate = nil
			best_candidate_score = 0
			Server.all().each do |server|
				if (server.free_cpu >= microservice.cpu and server.free_ram >= microservice.ram and server.free_disk >= microservice.disk)
					score = (server.free_cpu * server.free_ram * server.free_disk) ** (1.0/3)

					if (score > best_candidate_score or !best_candidate)
						best_candidate = server
						best_candidate_score = score
					end
				end

			end
			best_candidate.add_microservice(microservice) if (best_candidate)
		end
	end

	placement = []
	Microservice.all().each { |microservice| placement.push(microservice.server.id) }

	return(placement)
end

def int_ha()
	Application.all().sort_by { |application| -application.sla }.each do |application|
		application.microservices.each do |microservice|
			best_candidate = nil
			best_candidate_score = 0

			Server.all().each do |server|
				if (server.free_cpu >= microservice.cpu and server.free_ram >= microservice.ram and server.free_disk >= microservice.disk)
					server.free_cpu -= microservice.cpu
					server.free_ram -= microservice.ram
					server.free_disk -= microservice.disk

					######################
					#### Server score ####
					######################
					# Occupation Rate
					occupation = ((100 - ((server.free_cpu * 100) / server.cpu)) + (100 - ((server.free_ram * 100) / server.ram)) + (100 - ((server.free_disk * 100) / server.disk))) / 3.0

					# Interference Awareness
					colliding_microservices = server.microservices.select { |hosted_microservice| hosted_microservice.type == microservice.type }

					cpu_demand_of_colliding_microservices = 0
					ram_demand_of_colliding_microservices = 0
					disk_demand_of_colliding_microservices = 0
					colliding_microservices.each do |colliding_microservice|
						cpu_demand_of_colliding_microservices += colliding_microservice.cpu
						ram_demand_of_colliding_microservices += colliding_microservice.ram
						disk_demand_of_colliding_microservices += colliding_microservice.disk
					end

					occupation = ((100 - ((server.free_cpu * 100) / server.cpu)) + (100 - ((server.free_ram * 100) / server.ram)) + (100 - ((server.free_disk * 100) / server.disk))) / 3

					cpu_demand_of_colliding_microservices = (cpu_demand_of_colliding_microservices * 100.0) / server.cpu
					ram_demand_of_colliding_microservices = (ram_demand_of_colliding_microservices * 100.0) / server.ram
					disk_demand_of_colliding_microservices = (disk_demand_of_colliding_microservices * 100.0) / server.disk
					
					colliding_microservices_occupation = (cpu_demand_of_colliding_microservices + ram_demand_of_colliding_microservices + disk_demand_of_colliding_microservices) / 3

					# High Availability Awareness
					availability = server.availability

					score = (occupation + availability) / (1 + colliding_microservices.count())

					if (score > best_candidate_score or !best_candidate)
						best_candidate = server
						best_candidate_score = score
					end

					server.free_cpu += microservice.cpu
					server.free_ram += microservice.ram
					server.free_disk += microservice.disk
				end

			end
			best_candidate.add_microservice(microservice) if (best_candidate)
		end
	end

	placement = []
	Microservice.all().each { |microservice| placement.push(microservice.server.id) }
	return(placement)
end

def irene()
	population = Population.new(POPULATION_SIZE)
	# 2. Calculate Initial Population Fitness
	population.calculate_initial_population_fitness()

	while (population.generation < MAX_GENERATIONS)
		# 3. Selection
		parents = population.fitness_proportionate_selection()

		# 4. Crossover
		population.uniform_crossover(parents)

		# 5. Calculate Population Fitness
		population.calculate_fitness()

		# 6. Remove old solutions from the tabu list
		population.tabu_list.delete_if { |solution| population.generation - solution[:generation] > TABU_LIMIT }

		population.generation += 1
		puts("[#{population.generation}] #{population.chromosomes.last().fitness} => Items on the Tabu List: #{population.tabu_list.size()}")
	end
	return(population.chromosomes.last().genes)
end

# TODO: test out parameter combinations
START_TEMP = 100
COOL_RATE = 0.1
def temperature(k) # Function that maps time passed to temperature
	#Needs to converge to less than 0
	return START_TEMP - (COOL_RATE * k)
end

def simul_annealing()
	current = SimulAnnealing::State.new(nil)
	current.calculate_energy()

	for k in (0..)
		temp = temperature(k)
		if (temp <= 0)
			break # return current
		end
		neigh = current.neighbor()
		# TODO: ensure neighbor is unique
		neigh.calculate_energy() # TODO: work out relationship between energy and temperature
		delta = neigh.energy - current.energy

		stats = "cur:#{current.energy} neigh:#{neigh.energy} delta:#{delta} temp:#{temp}"

		if (delta < 0) # always accept better solutions
			puts "good: #{stats}\n"
			current = neigh
			next
		end

		prob = Math.exp(-delta / temp)
		stats = "#{stats} prob:#{prob}"

		if prob > Random.rand() # maybe accept bad solution
			puts "luck: #{stats}\n"
			current = neigh
		else
			puts "skip: #{stats}\n"
		end
	end
	return(current.config)
end

read_json_input("datasets/dataset_#{SCENARIO}.json")

servers = Server.all()
apps = Application.all()
microservices = Microservice.all()
solution = ARGV[0]
# Valid options for ARGV[0]: 'irene', 'int_ha', 'best-fit', 'first-fit', 'worst-fit', 'simul-annealing'

initial_time = Time.now()
placement = placement_policy(solution)
execution_time = Time.now() - initial_time

show_results(solution, placement, execution_time)
