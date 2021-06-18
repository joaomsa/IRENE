def read_json_input(json_file)
	servers = []
	applications = []
	microservices = []

	# Reads the JSON input file
	input_file = JSON.parse(File.read(json_file))

	# Creates servers
	input_file['servers'].each do |server|
		new_server = Server.new(server['id'], server['cpu'], server['ram'], server['disk'], server['availability'])
		servers.push(new_server)
	end

	# Creates applications and microservices
	input_file['applications'].each do |application|
		new_application = Application.new(application['id'], application['sla'])
		applications.push(new_application)

		# Creates microservices of this application
		application['microservices'].each do |microservice|
			new_microservice = Microservice.new(microservice['id'], microservice['cpu'], microservice['ram'], microservice['disk'], microservice['type'])
			microservices.push(new_microservice)

			# Attaches the created microservice to the current application
			new_application.add_microservice(new_microservice)
		end
	end
end

def placement_policy(strategy)
	return(irene()) if (strategy.downcase() == 'irene')
	return(first_fit()) if (strategy.downcase() == 'first-fit')
	return(best_fit()) if (strategy.downcase() == 'best-fit')
	return(worst_fit()) if (strategy.downcase() == 'worst-fit')
	return(int_ha()) if (strategy.downcase() == 'int_ha')
	return(simul_annealing()) if (strategy.downcase() == 'simul-annealing')
end

def show_results(solution, placement, execution_time)
	servers = Server.all()
	apps = Application.all()
	microservices = Microservice.all()

	for i in 0...servers.size()
		servers[i].reset_resources_demand()
	end

	placement.each_with_index do |server_id, microservice_id|
		server = Server.find_by_id(server_id)
		microservice = Microservice.find_by_id(microservice_id)

		server.add_microservice(microservice)
	end
	#############################################
	#### Printing out the provided placement ####
	#############################################
	if (VERBOSITY >= 1)
		puts("\n\n---- Placement ----")
		Application.all().each do |application|
			puts("\n\nApp_#{application.id}")
			puts("SLA: #{application.sla}")
			puts("Availability: #{application.calculate_availability()}")
			if (VERBOSITY >= 2)
				application.microservices.each do |microservice|
					puts("    MS_#{microservice.id} (#{microservice.type}) -> #{microservice.server.id}")
				end
			end
		end
		puts("\n\n")
	end

	#######################################
	#### Calculating High Availability ####
	#######################################
	sla_violations = 0
	average_sla_violation = 0

	availability_low_priority_apps = []
	availability_medium_priority_apps = []
	availability_high_priority_apps = []

	applications_slas = []
	Application.all().each do |application|
		applications_slas.push(application.sla)
	end
	applications_slas = applications_slas.uniq().sort()
	low_availability_sla = applications_slas[0]
	medium_availability_sla = applications_slas[1]
	high_availability_sla = applications_slas[2]

	Application.all().each do |application|
		if (application.calculate_availability() < application.sla)
			sla_violations += 1
			average_sla_violation += 100 - ((application.calculate_availability() * 100.0) / application.sla)
		end

		if (application.sla == low_availability_sla)
			availability_low_priority_apps.push(application.calculate_availability())
		elsif (application.sla == medium_availability_sla)
			availability_medium_priority_apps.push(application.calculate_availability())
		elsif (application.sla == high_availability_sla)
			availability_high_priority_apps.push(application.calculate_availability())
		end
	end

	average_sla_violation = average_sla_violation / Application.count()

	avg_availability_low_priority_apps = availability_low_priority_apps.sum() / availability_low_priority_apps.count()
	avg_availability_medium_priority_apps = availability_medium_priority_apps.sum() / availability_medium_priority_apps.count()
	avg_availability_high_priority_apps = availability_high_priority_apps.sum() / availability_high_priority_apps.count()

	#########################################################
	#### Calculating Interference and Consolidation Rate ####
	#########################################################
	colliding_microservices = 0
	used_servers = 0
	unused_servers = 0
	Server.all().each do |server|
		if (server.microservices.count() > 0)
			used_servers += 1
		else
			unused_servers += 1
		end
		colliding_microservices += server.get_number_of_colliding_microservices()
	end

	consolidation_rate = (unused_servers * 100.0) / Server.count()
	##########################
	#### Printing Results ####
	##########################
	if (VERBOSITY >= 2)
		Application.all().sort_by(&:sla).each do |application|
			puts("App_#{application.id}. SLA: #{application.sla}. Microservices: #{application.microservices.count()}. Availability: #{application.calculate_availability()}")
		end
		puts("\n\navg_availability_low_priority_apps = #{avg_availability_low_priority_apps}")
		puts("avg_availability_medium_priority_apps = #{avg_availability_medium_priority_apps}")
		puts("avg_availability_high_priority_apps = #{avg_availability_high_priority_apps}\n\n")
	end

	score = calculate_score(placement)
	csv_metrics = [SCENARIO, solution, execution_time, sla_violations, average_sla_violation, avg_availability_low_priority_apps, avg_availability_medium_priority_apps, avg_availability_high_priority_apps, colliding_microservices, used_servers, consolidation_rate, score]
	puts("Solution: #{solution}")
	puts("SLA Violations: #{sla_violations} (#{average_sla_violation}\% in average)")
	puts("Colliding Microservices: #{colliding_microservices}")
	puts("Used Servers: #{used_servers}")
	puts("Consolidation Rate: #{consolidation_rate.round(4)}")
	puts("Execution Time: #{execution_time}")
	puts("Score: #{score}")
	puts("\n\nPlacement: #{placement}\n\n")
	puts("CSV:\n#{csv_metrics}")
end

def calculate_score(placement)
	###############
	#### Goals ####
	###############
	# Goal 1: Minimize interference
	# Goal 2: Maximize HA
	# Goal 3: Maximize consolidation rate
	#####################
	#### Constraints ####
	#####################
	# Respecting servers capacity

	#######################################
	#### Calculating the fitness score ####
	#######################################
	# Resetting placement
	servers = Server.all()

	for i in 0...servers.size()
		servers[i].reset_resources_demand()
	end
	
	# Performing the suggested placement
	for i in 0...placement.size()
		server = Server.find_by_id(placement[i])
		microservice = Microservice.find_by_id(i)

		server.add_microservice(microservice)
	end

	overloaded_servers = 0
	colliding_microservices = 0
	servers_consolidation = 0

	Server.all().each do |server|
		# Consolidation
		if (server.microservices.count() == 0)
			servers_consolidation += 1
		end

		# Servers capacity
		if (server.free_cpu < 0 or server.free_ram < 0 or server.free_disk < 0)
			overloaded_servers += 1
		end

		# Interference
		colliding_microservices += server.get_number_of_colliding_microservices()
	end

	servers_consolidation = (servers_consolidation * 100.0) / Server.count()
	interference_score =  100 - ((colliding_microservices * 100.0) / Microservice.count())

	sla_violations = []
	Application.all().each do |application|
		if (application.calculate_availability() < application.sla)
			sla_violations.push(application.sla - application.calculate_availability())
		end
	end
	number_of_sla_violations = 100 - ((sla_violations.count() * 100.0) / Application.count())
	if (sla_violations.count() == 0)
		sla_violations_gravity = 100
	else
		sla_violations_gravity = 100 - (sla_violations.sum() / sla_violations.count())
	end

	score = (interference_score + number_of_sla_violations + sla_violations_gravity + servers_consolidation) ** FITNESS_POWER

	score = score - (score * overloaded_servers)

	# Resetting placement
	for i in 0...servers.size()
		servers[i].reset_resources_demand()
	end

	return(score)
end
