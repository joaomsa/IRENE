##########################
### General Parameters ###
##########################
# Dataset size
DATASET_NAME = 'baseline'

#################
### Servers ###
#################
# Servers Availability
HIGH_AVAILABILITY = 99.9
MEDIUM_AVAILABILITY = 95
LOW_AVAILABILITY = 90

# Number of Servers per size
SMALL_SERVERS = 0
MEDIUM_SERVERS = 60
LARGE_SERVERS = 0

# Server specs
SMALL_SERVER = { cpu: 8, ram:8, disk: 64 }
MEDIUM_SERVER = { cpu: 16, ram: 16, disk: 128 }
LARGE_SERVER = { cpu: 32, ram: 32, disk: 256 }

HIGH_AVAILABLE_SERVERS = 10
MEDIUM_AVAILABLE_SERVERS = 20
LOW_AVAILABLE_SERVERS = 30

####################
### Applications ###
####################
# Availability SLA
LOW_SLA = 80
MEDIUM_SLA = 85
HIGH_SLA = 90

# Number of applications per size
SMALL_APPLICATIONS = 6
MEDIUM_APPLICATIONS = 6
LARGE_APPLICATIONS = 6

# Defining availability SLAs
LOW_PRIORITY_SMALL_APPLICATIONS = 2
LOW_PRIORITY_MEDIUM_APPLICATIONS = 2
LOW_PRIORITY_LARGE_APPLICATIONS = 2

MEDIUM_PRIORITY_SMALL_APPLICATIONS = 2
MEDIUM_PRIORITY_MEDIUM_APPLICATIONS = 2
MEDIUM_PRIORITY_LARGE_APPLICATIONS = 2

HIGH_PRIORITY_SMALL_APPLICATIONS = 2
HIGH_PRIORITY_MEDIUM_APPLICATIONS = 2
HIGH_PRIORITY_LARGE_APPLICATIONS = 2

# Number of microservice per application size
MICROSERVICES_SMALL_APPLICATIONS = 3
MICROSERVICES_MEDIUM_APPLICATIONS = 6
MICROSERVICES_LARGE_APPLICATIONS = 9

#####################
### Microservices ###
#####################
# Total number of microservices
MICROSERVICES = SMALL_APPLICATIONS * MICROSERVICES_SMALL_APPLICATIONS + MEDIUM_APPLICATIONS * MICROSERVICES_MEDIUM_APPLICATIONS + LARGE_APPLICATIONS * MICROSERVICES_LARGE_APPLICATIONS

# Percentage of microservices per type
CPU_BOUND = (MICROSERVICES / 3.0).ceil()
MEMORY_BOUND = ((MICROSERVICES - CPU_BOUND) / 2.0).ceil()
IO_BOUND = MICROSERVICES - (CPU_BOUND + MEMORY_BOUND)

# Percentage of microservices per size
SMALL_MICROSERVICES = (MICROSERVICES / 3.0).ceil()
MEDIUM_MICROSERVICES = ((MICROSERVICES - SMALL_MICROSERVICES) / 2.0).ceil()
LARGE_MICROSERVICES =  MICROSERVICES - (SMALL_MICROSERVICES + MEDIUM_MICROSERVICES)

# Microservice specs
SMALL_MICROSERVICE = { cpu: 1, ram: 1, disk: 8 }
MEDIUM_MICROSERVICE = { cpu: 2, ram: 2, disk: 16 }
LARGE_MICROSERVICE = { cpu: 4, ram: 4, disk: 32 }

SEED = 1011
srand(SEED)

########################
### Creating Objects ###
########################
# Creating Servers
servers = []
SMALL_SERVERS.times do
	servers.push({ id: servers.size(), cpu: SMALL_SERVER[:cpu], ram: SMALL_SERVER[:ram], disk: SMALL_SERVER[:disk] })
end
MEDIUM_SERVERS.times do
	servers.push({ id: servers.size(), cpu: MEDIUM_SERVER[:cpu], ram: MEDIUM_SERVER[:ram], disk: MEDIUM_SERVER[:disk] })
end
LARGE_SERVERS.times do
	servers.push({ id: servers.size(), cpu: LARGE_SERVER[:cpu], ram: LARGE_SERVER[:ram], disk: LARGE_SERVER[:disk] })
end

servers = servers.shuffle(random: Random.new(SEED))

servers_availability = []
HIGH_AVAILABLE_SERVERS.times { servers_availability.push(HIGH_AVAILABILITY) }
MEDIUM_AVAILABLE_SERVERS.times { servers_availability.push(MEDIUM_AVAILABILITY) }
LOW_AVAILABLE_SERVERS.times { servers_availability.push(LOW_AVAILABILITY) }

servers.each_with_index do |server, i|
	server[:id] = i
	server[:availability] = servers_availability[i]
end

# Creating Applications and Microservices
applications = []
created_microservices = 0

small_applications_slas = []
LOW_PRIORITY_SMALL_APPLICATIONS.times { small_applications_slas.push(LOW_SLA) }
MEDIUM_PRIORITY_SMALL_APPLICATIONS.times { small_applications_slas.push(MEDIUM_SLA) }
HIGH_PRIORITY_SMALL_APPLICATIONS.times { small_applications_slas.push(HIGH_SLA) }

medium_applications_slas = []
LOW_PRIORITY_MEDIUM_APPLICATIONS.times { medium_applications_slas.push(LOW_SLA) }
MEDIUM_PRIORITY_MEDIUM_APPLICATIONS.times { medium_applications_slas.push(MEDIUM_SLA) }
HIGH_PRIORITY_MEDIUM_APPLICATIONS.times { medium_applications_slas.push(HIGH_SLA) }

large_applications_slas = []
LOW_PRIORITY_LARGE_APPLICATIONS.times { large_applications_slas.push(LOW_SLA) }
MEDIUM_PRIORITY_LARGE_APPLICATIONS.times { large_applications_slas.push(MEDIUM_SLA) }
HIGH_PRIORITY_LARGE_APPLICATIONS.times { large_applications_slas.push(HIGH_SLA) }

puts("large_applications_slas = #{large_applications_slas}\n\n")

SMALL_APPLICATIONS.times do |i|
	app_microservices = []

	local_seed = rand(SEED)

	# Microservice Resource Bounds
	resource_bounds = []
	microservice_sizes = []

	(MICROSERVICES_SMALL_APPLICATIONS / 3).times do
		resource_bounds.push('cpu-bound')
		microservice_sizes.push([SMALL_MICROSERVICE[:cpu], SMALL_MICROSERVICE[:ram], SMALL_MICROSERVICE[:disk]])
	end
	(MICROSERVICES_SMALL_APPLICATIONS / 3).times do
		resource_bounds.push('io-bound')
		microservice_sizes.push([MEDIUM_MICROSERVICE[:cpu], MEDIUM_MICROSERVICE[:ram], MEDIUM_MICROSERVICE[:disk]])
	end
	(MICROSERVICES_SMALL_APPLICATIONS / 3).times do
		resource_bounds.push('memory-bound')
		microservice_sizes.push([LARGE_MICROSERVICE[:cpu], LARGE_MICROSERVICE[:ram], LARGE_MICROSERVICE[:disk]])
	end

	resource_bounds.shuffle!(random: Random.new(local_seed))
	microservice_sizes.shuffle!(random: Random.new(local_seed))

	# Creating Microservices
	MICROSERVICES_SMALL_APPLICATIONS.times do

		app_microservices.push({ id: created_microservices, type: resource_bounds[app_microservices.size()], cpu: microservice_sizes[app_microservices.size()][0], ram: microservice_sizes[app_microservices.size()][1], disk: microservice_sizes[app_microservices.size()][2] })

		created_microservices += 1
	end

	applications.push({ id: applications.size(), microservices: app_microservices, sla: small_applications_slas[i] })
end

MEDIUM_APPLICATIONS.times do |i|
	app_microservices = []

	local_seed = rand(SEED)

	# Microservice Resource Bounds
	resource_bounds = []
	microservice_sizes = []

	(MICROSERVICES_MEDIUM_APPLICATIONS / 3).times do
		resource_bounds.push('cpu-bound')
		microservice_sizes.push([SMALL_MICROSERVICE[:cpu], SMALL_MICROSERVICE[:ram], SMALL_MICROSERVICE[:disk]])
	end
	(MICROSERVICES_MEDIUM_APPLICATIONS / 3).times do
		resource_bounds.push('io-bound')
		microservice_sizes.push([MEDIUM_MICROSERVICE[:cpu], MEDIUM_MICROSERVICE[:ram], MEDIUM_MICROSERVICE[:disk]])
	end
	(MICROSERVICES_MEDIUM_APPLICATIONS / 3).times do
		resource_bounds.push('memory-bound')
		microservice_sizes.push([LARGE_MICROSERVICE[:cpu], LARGE_MICROSERVICE[:ram], LARGE_MICROSERVICE[:disk]])
	end

	resource_bounds.shuffle!(random: Random.new(local_seed))
	microservice_sizes.shuffle!(random: Random.new(local_seed))

	# Creating Microservices
	MICROSERVICES_MEDIUM_APPLICATIONS.times do

		app_microservices.push({ id: created_microservices, type: resource_bounds[app_microservices.size()], cpu: microservice_sizes[app_microservices.size()][0], ram: microservice_sizes[app_microservices.size()][1], disk: microservice_sizes[app_microservices.size()][2] })

		created_microservices += 1
	end

	applications.push({ id: applications.size(), microservices: app_microservices, sla: medium_applications_slas[i] })
end

LARGE_APPLICATIONS.times do |i|
	app_microservices = []

	local_seed = rand(SEED)

	# Microservice Resource Bounds
	resource_bounds = []
	microservice_sizes = []

	(MICROSERVICES_LARGE_APPLICATIONS / 3).times do
		resource_bounds.push('cpu-bound')
		microservice_sizes.push([SMALL_MICROSERVICE[:cpu], SMALL_MICROSERVICE[:ram], SMALL_MICROSERVICE[:disk]])
	end
	(MICROSERVICES_LARGE_APPLICATIONS / 3).times do
		resource_bounds.push('io-bound')
		microservice_sizes.push([MEDIUM_MICROSERVICE[:cpu], MEDIUM_MICROSERVICE[:ram], MEDIUM_MICROSERVICE[:disk]])
	end
	(MICROSERVICES_LARGE_APPLICATIONS / 3).times do
		resource_bounds.push('memory-bound')
		microservice_sizes.push([LARGE_MICROSERVICE[:cpu], LARGE_MICROSERVICE[:ram], LARGE_MICROSERVICE[:disk]])
	end

	resource_bounds.shuffle!(random: Random.new(local_seed))
	microservice_sizes.shuffle!(random: Random.new(local_seed))

	# Creating Microservices
	MICROSERVICES_LARGE_APPLICATIONS.times do

		app_microservices.push({ id: created_microservices, type: resource_bounds[app_microservices.size()], cpu: microservice_sizes[app_microservices.size()][0], ram: microservice_sizes[app_microservices.size()][1], disk: microservice_sizes[app_microservices.size()][2] })

		created_microservices += 1
	end

	applications.push({ id: applications.size(), microservices: app_microservices, sla: large_applications_slas[i] })

end

applications.each do |application|
	puts("\n\nApp_#{application[:id]}. SLA: #{application[:sla]}")

	application[:microservices].each do |microservice|
		puts("    #{microservice}")
	end
end
applications.shuffle!(random: Random.new(SEED))
applications.each_with_index do |application, i|
	application[:id] = i
end

puts("All Applications:")
applications.each_with_index do |application, i|
	puts("App_#{i}. Microservices: #{application[:microservices].size()}. SLA: #{application[:sla]}")
end
puts("\n\n")

puts("Servers: #{SMALL_SERVERS + MEDIUM_SERVERS + LARGE_SERVERS}")
puts("    Small: #{SMALL_SERVERS}")
puts("    Medium: #{MEDIUM_SERVERS}")
puts("    Large: #{LARGE_SERVERS}")

puts("Applications: #{SMALL_APPLICATIONS + MEDIUM_APPLICATIONS + LARGE_APPLICATIONS}")
puts("    Small: #{SMALL_APPLICATIONS}")
puts("    Medium: #{MEDIUM_APPLICATIONS}")
puts("    Large: #{LARGE_APPLICATIONS}")

puts("Microservices: #{MICROSERVICES}")
puts("    Small: #{SMALL_MICROSERVICES}")
puts("    Medium: #{MEDIUM_MICROSERVICES}")
puts("    Large: #{LARGE_MICROSERVICES}\n\n")
puts("    CPU-B: #{CPU_BOUND}")
puts("    MEM-B: #{MEMORY_BOUND}")
puts("    IO-B: #{IO_BOUND}")

#############################################
### Saving generated input to a JSON file ###
#############################################
require('json')
File.open("datasets/dataset_#{DATASET_NAME}.json","w") do |file|
	file.write(JSON.pretty_generate({ "servers": servers, "applications": applications }))
end
