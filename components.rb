class Object
	def all()
		return(self.instances.sort_by(&:id))
	end

	def count()
		return(self.instances.size())
	end

	def sample()
		return(self.instances.sample())
	end

	def find_by_id(id)
		return(self.instances.detect { |instance| instance.id == id })
	end
end

class Server < Object

	# List of instances of this class
	@@instances = []

	# Constructor
	attr_accessor(:id, :availability, :cpu, :ram, :disk, :free_cpu, :free_ram, :free_disk, :microservices)
	def initialize(id, cpu, ram, disk, availability)
		# Identifier
		@id = id

		# Total capacity
		@cpu = cpu
		@ram = ram
		@disk = disk

		# Free resources
		@free_cpu = cpu
		@free_ram = ram
		@free_disk = disk

		# Availability
		@availability = availability

		# List of microservices hosted by this server
		@microservices = []
	
		# Add the created object to the list of instances of this class
		@@instances.push(self)
	end

	def add_microservice(microservice)
		@microservices.push(microservice)
		microservice.server = self

		@free_cpu -= microservice.cpu
		@free_ram -= microservice.ram
		@free_disk -= microservice.disk
	end

	def remove_microservice(microservice)
		@microservices -= [microservice]

		microservice.server = nil

		@free_cpu += microservice.cpu
		@free_ram += microservice.ram
		@free_disk += microservice.disk
	end

	def calculate_resources_demand()
		@free_cpu = @cpu
		@free_ram = @ram
		@free_disk = @disk

		for i in 0...@microservices.size()
			@free_cpu -= @microservices[i].cpu
			@free_ram -= @microservices[i].ram
			@free_disk -= @microservices[i].disk
		end

	end
	def get_number_of_microservices_by_type(type)
		hosted_microservice_of_the_selected_type = 0

		for i in 0...@microservices.size()
			hosted_microservice_of_the_selected_type += 1 if (@microservices[i].type == type)
		end

		return(hosted_microservice_of_the_selected_type)
	end
	def get_number_of_colliding_microservices()

		colliding_cpu_bound_microservices = get_number_of_microservices_by_type('cpu-bound')
		colliding_io_bound_microservices = get_number_of_microservices_by_type('io-bound')
		colliding_memory_bound_microservices = get_number_of_microservices_by_type('memory-bound')
	
		colliding_cpu_bound_microservices = 0 if (colliding_cpu_bound_microservices == 1)
		colliding_io_bound_microservices = 0 if (colliding_io_bound_microservices == 1)
		colliding_memory_bound_microservices = 0 if (colliding_memory_bound_microservices == 1)

		return(colliding_cpu_bound_microservices + colliding_io_bound_microservices + colliding_memory_bound_microservices)
	end
	def reset_resources_demand()
		@free_cpu = @cpu
		@free_ram = @ram
		@free_disk = @disk

		for i in 0...@microservices.size()
			@microservices[i].server = nil
		end

		@microservices = []
	end

	def to_s()
		microservices = []

		for i in 0...@microservices.size()
			microservices.push(@microservices[i].id)
		end

		return("PM_#{@id}. Capacity: [#{@cpu}, #{@ram}, #{@disk}]. Free: [#{@free_cpu}, #{@free_ram}, #{@free_disk}]. Microservices: #{microservices}")
	end

	def self.instances
		return(@@instances)
	end
end

class Application < Object

	# List of instances of this class
	@@instances = []

	attr_accessor(:id, :microservices, :sla)
	# Constructor
	def initialize(id, sla)
		# Identifier
		@id = id

		# List of microservices that compose the application
		@microservices = []

		# Application's availability SLA
		@sla = sla

		# Add the created object to the list of instances of this class
		@@instances.push(self)
	end

	def add_microservice(microservice)
		@microservices.push(microservice)
		microservice.application = self
	end

	def get_host_servers()
		host_servers = []

		for i in 0...@microservices.size()
			host_servers.push(@microservices[i].server) if (@microservices[i].server)
		end

		return(host_servers.uniq())
	end

	def calculate_availability()
		availability = 0.0

		for i in 0...@microservices.size()
			if (i == 0)
				availability = (@microservices[i].server.availability) / 100.0
			else
				availability *= (@microservices[i].server.availability) / 100.0
			end
		end

		return(availability * 100)
	end

	def self.instances
		return(@@instances)
	end

	def to_s()
		microservices = []

		for i in 0...@microservices.size()
			microservices.push(@microservices[i].id)
		end

		return("App_#{@id}. Microservices (#{@microservices.size()}): #{microservices}.")
	end
end

class Microservice < Object

	# List of instances of this class
	@@instances = []

	attr_accessor(:id, :cpu, :ram, :disk, :type, :application, :server)
	def initialize(id, cpu, ram, disk, type)
		# Identifier
		@id = id

		# Total demand
		@cpu = cpu
		@ram = ram
		@disk = disk

		# Microservice's resource bound
		@type = type

		# Application of which this microservice is part of
		@application = nil

		# Server that hosts this microservice
		@server = nil

		# Add the created object to the list of instances of this class
		@@instances.push(self)
	end

	def self.instances
		return(@@instances)
	end

	def to_s()
		return("Microservice_#{@id}. Type: #{@type}. Demand: [#{@cpu}, #{@ram}, #{@disk}]. App: #{@application.id if (@application)}. Server: #{@server.id if (@server)}.")
	end
end
