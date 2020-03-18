require('csv')

DATASETS = ['baseline', 'app_size_scenario1', 'app_size_scenario2', 'sla_scenario1', 'sla_scenario2']
HEURISTICS = ['best-fit', 'first-fit', 'worst-fit', 'int_ha', 'irene']
CPU = 7
EXECUTIONS = 15

results = []

DATASETS.each do |dataset|
	EXECUTIONS.times do |execution|
		HEURISTICS.each do |heuristic|
			output = `taskset -c #{CPU} ruby --jit placement_policies.rb '#{heuristic}' '#{dataset}'`
			
			sleep(5)
			
			# Getting results for the CSV file
			results.push(eval(output.split("\n").last()))

			# Saving the verbose output to a txt file inside the 'results' directory
			File.write("#{__dir__}/results/#{heuristic}-#{dataset}-#{execution}.txt", output)
		end
	end
end

# csv_metrics = [solution, sla_violations, average_sla_violation, avg_availability_low_priority_apps, avg_availability_medium_priority_apps, avg_availability_high_priority_apps, colliding_microservices, Server.count(), used_servers, consolidation_rate, score, execution_time]
CSV.open("#{__dir__}/results.csv", "wb", col_sep: "\t") do |csv|
	# CSV Header
	csv << ['Scenario', 'Strategy', 'Execution Time', 'SLA Violations', 'SLA Violation per App', 'Availability Low SLA Apps', 'Availability Medium SLA Apps', 'Availability High SLA Apps', 'Colliding Microservices', 'Used Servers', 'Consolidation Rate', 'Fitness Score']

	# CSV Body
	results.each do |result|
		csv << result
	end
end
