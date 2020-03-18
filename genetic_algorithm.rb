POPULATION_SIZE = 500
MUTATION_RATE = 0.35
N_PARENTS = 100
FITNESS_POWER = 2
MAX_GENERATIONS = 25000
TABU_LIMIT = 50

class Population
	attr_accessor(:size, :generation, :chromosomes, :tabu_list)
	def initialize(size)
		@size = size

		@chromosomes = []

		@generation = 1

		@tabu_list = []

		@size.times do
			@chromosomes.push(Chromosome.new(self, nil))
		end
	end
	def calculate_initial_population_fitness()
		for i in 0...@chromosomes.size()
			@chromosomes[i].calculate_fitness()
		end
	end
	def calculate_fitness()
		@chromosomes.sort_by!(&:fitness)
	end
	def calculate_fitness_sum()
		fitness_sum = 0.0

		for i in 0...@chromosomes.size()
			fitness_sum += @chromosomes[i].fitness
		end

		return(fitness_sum)
	end
	def fitness_proportionate_selection()
		selection_options = []
		fitness_sum = calculate_fitness_sum()

		if (fitness_sum == 0)
			selection_options = @chromosomes
		else
			for i in 0...@chromosomes.size()
				if (@chromosomes[i].fitness > 0)
					((@chromosomes[i].fitness / fitness_sum) * 100).ceil().times do
						selection_options.push(@chromosomes[i])
					end
				end
			end
		end

		parents = []
		while (parents.size() < N_PARENTS)
			parent = @chromosomes.sample()

			parents.push(parent) if (!parents.include?(parent))
		end

		return(parents)
	end
	def rank_selection()
		return(@chromosomes.last(N_PARENTS))
	end
	def uniform_crossover(parents)
		for i in (0...parents.size()).step(2) do
			# Crossover
			child_genes = swap_genes([parents[i], parents[i + 1]])
			while (tabu_penalty(child_genes))
				child_genes = swap_genes([parents[i], parents[i + 1]])
			end

			# Update the population
			offspring = Chromosome.new(self, child_genes)

			@chromosomes.push(offspring)
			
			offspring.calculate_fitness()
			calculate_fitness()

			@tabu_list.push({ genes: @chromosomes[0].genes, generation: @generation })

			@chromosomes -= [@chromosomes[0]]
		end
	end
	def swap_genes(parents)
		child_genes = []

		for j in 0...parents.first().genes.size() do
			random_parent_id = [0, 1].sample()
			child_genes[j] = parents[random_parent_id].genes[j]
		end

		# Mutation based on predefined probability
		if (Random.rand((0.0)..1) > 1 - MUTATION_RATE)
			child_genes[Random.rand(0...child_genes.size())] = Server.sample().id
		end

		return(child_genes)
	end
	def tabu_penalty(genes)
		@tabu_list.each do |solution|
			return(true) if (genes == solution[:genes])
		end

		return(false)
	end
end
class Chromosome
	attr_accessor(:population, :genes, :fitness)
	def initialize(population, genes)
		@population = population
		@fitness = 0.0

		if (genes)
			@genes = genes
		else
			@genes = []
			Microservice.count().times do
				@genes.push(Server.sample().id)
			end
		end
	end
	def to_s()
		"#{@genes}"
	end
	def calculate_fitness()
		@fitness = calculate_score(@genes)
	end
end
