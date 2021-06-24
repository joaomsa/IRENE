#!/usr/bin/env ruby

require('json')
require('csv')
require('time')
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

START_TEMP = 1e5
TIME_STEP = 0.5 # Streches out or shortens the annealing duration (resulting in more iterations)
TEMP_THRESHOLD = 1e-5 # Annealing stops once temp drops below this value
VERY_FAST_DECAY = 0.303 # Used to control very fast cooling schedule's logarithimic decay constant
VERY_FAST_QUENCH = 2.0 # Used to control very fast cooling schedule's quench constant
# Once annealing passes a low energy threshold (where probability of
# random jumps is much, much lower), if we're not making any more
# improvements then we've likely reached a local minima and should stop
RESTARTS = 10
WRITE_CSV = false

def temperature(k)
	# Function that maps time passed to temperature
	# Applies logarithmic decay to initial temperature (based on very fast paper)

	# Tried boltzmann, and cauchy strategies but didn't yield better results
	
	# Continuous logarithimic compounding
	k = k * TIME_STEP
 	return START_TEMP * Math.exp(-VERY_FAST_DECAY * (k ** (1.0/VERY_FAST_QUENCH)))
end

def simul_annealing()

	best = nil
	#best = SimulAnnealing::State.new(nil)
	#best.calculate_energy()

	if WRITE_CSV
		csv_name = "exec-#{SCENARIO}-#{Time.now.to_i}-#{Random.rand(100)}.csv"
		csv = CSV.open("#{__dir__}/results_simul_annealing/#{csv_name}", "wb", col_sep: "\t")
	end

	for trial in (0..RESTARTS)
		# NOTE: Actually starting from the previous trial's state
		# results in less colisions/sla violations (at least for
		# baseline)
		#current = best # each restart starts from the best
		current = SimulAnnealing::State.new(nil)
		current.calculate_energy()

		if (!best)
			best = current
		end

		if WRITE_CSV then csv << ["trial", "k", "temp", "best", "cur", "delta", "prob"] end
		for k in (0..)
			temp = temperature(k)
			if (temp <= TEMP_THRESHOLD)
				break # return current
			end
			neigh = current.neighbor()
			# TODO: ensure neighbor is unique
			neigh.calculate_energy()
			 # NOTE: Worked out relationship between energy and temperature:
			 # probability function is sensitive to average delta E,
			 # starting temperature was tuned to match the model's
			 # average delta between moves: ~18
			delta = neigh.energy.delta(current.energy)

			stats = "trial: %i temp: %.5f best: %.4f cur: %.4f neigh: %.4f delta: %.4f" % [
				trial, temp, best.energy.total, current.energy.total, neigh.energy.total, delta
			]

			if delta < 0 # always accept better solutions
				current = neigh
				if current.energy.delta(best.energy) < 0
					best = current
				end

				#puts "good: #{stats}\n"
				if WRITE_CSV then csv << [trial, k, temp, best.energy.total, current.energy.total, delta, 1.0, "good"] end
				next
			end

			prob = Math.exp(-delta / temp)
			if prob > Random.rand() # maybe accept bad solution
				current = neigh

				#puts "luck: #{stats} prob: #{prob}\n"
				if WRITE_CSV then csv << [trial, k, temp, best.energy.total, current.energy.total, delta, prob, "luck"] end
			else
				#puts "skip: #{stats}\n"
			end
		end

		puts "trial: %i best: %.4f (sla(c):%.4f, sla(g):%.4f, col:%.4f) k: %i\n" % [
			trial, best.energy.total,
			best.energy.sla_violation, best.energy.sla_gravity, best.energy.interference,
			k]
	end

	if WRITE_CSV then csv.close() end

	return(best.config)
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
