#require 'pry'
module SimulAnnealing
	class State
		attr_accessor(:config, :energy)
		def initialize(config)
			@energy = 0.0

			if (config)
				@config = config
			else
				@config = []
				Microservice.count().times do
					@config.push(Server.sample().id)
				end
			end
		end

		def neighbor()
			neighbor_config = @config.dup
			# neighbors are all solutions that are 1 move away from configuration as
			# defined by hamming distance (any 1 substitution)
			i = Random.rand(0...@config.size())

			while true do
				server_id = Server.sample().id
				if (server_id != neighbor_config[i])
					neighbor_config[i] = server_id
					break
				end
			end 
			return State.new(neighbor_config)
		end

		def to_s()
			"#{@config}"
		end

		def calculate_energy()
		  @energy = SimulAnnealing.calculate_energy_p(@config)
		end
	end

	def SimulAnnealing.calculate_energy_p(placement)
		#binding.pry
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

		servers_active = 0

		Server.all().each do |server|
			# Consolidation
			if (server.microservices.count() != 0)
				servers_active += 1
			end

			# Servers capacity
			if (server.free_cpu < 0 or server.free_ram < 0 or server.free_disk < 0)
				overloaded_servers += 1
			end

			# Interference
			colliding_microservices += server.get_number_of_colliding_microservices()
		end

		consolidation_energy = servers_active.to_f / Server.count()
		overloaded_energy = overloaded_servers.to_f / Server.count()
		interference_energy = colliding_microservices.to_f / Microservice.count()

		sla_violations = []
		Application.all().each do |application|
			if (application.calculate_availability() < application.sla)
				sla_violations.push(application.sla - application.calculate_availability())
			end
		end

 		sla_violation_energy = sla_violations.count().to_f / Application.count()
 
#		if (sla_violations.count() == 0)
#			sla_violations_gravity = 0
#		else
#			sla_violations_gravity = (sla_violations.sum() / sla_violations.count())
#		end

		energy = (consolidation_energy + sla_violation_energy + interference_energy)
		#energy = energy * (1 + overloaded_servers)
		energy = energy * 1000

		# Resetting placement
		for i in 0...servers.size()
			servers[i].reset_resources_demand()
		end

		return(energy)
	end
end
