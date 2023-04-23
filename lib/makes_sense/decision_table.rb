require_relative "result"
require_relative "values"

module MakesSense
  class DecisionTable
    def initialize(name, conditions, result_table)
      @name = name
      @conditions = conditions
      @result_table = result_table
    end

    def self.define(name, &block)
      dsl = DecisionTableDsl.new
      dsl.instance_eval(&block)
      new(name, dsl.conditions, dsl.result_table)
    end

    def validate
      cond_values = @conditions.map(&:values)
      cond_possibilities = cond_values[0].product(*cond_values[1..])
      result_possibilities = @result_table.rows.map(&:conditions)

      errors = []

      cond_possibilities.each do |cond_possibility|
        unless result_possibilities.include?(cond_possibility)
          errors << {
            message: "Missing result condition: #{cond_possibility}",
            expected_conditions: cond_possibility,
            expected: {}.tap do |condition_map|
              @conditions.each_with_index do |condition, index|
                condition_map[condition.name] = cond_possibility[index]
              end
            end
          }
        end
      end

      if !errors.empty?
        Failure.new(errors)
      else
        Success.new(self)
      end
    end

    private

    Value = Struct.new(:value)

    def possibility_graph
      Graph.new.tap do |graph|
        @conditions.reduce do |cond1, cond2|
          graph.add_edge(cond1, cond2)
          cond2
        end

        binding.pry
      end
    end
  end

  Condition = Struct.new(:name, :values)
  ResultTable = Struct.new(:rows)
  Row = Struct.new(:conditions, :results)

  class DecisionTableDsl
    include Values

    attr_reader :conditions, :result_table

    def initialize
      @conditions = []
      @result_table = nil
    end

    def cond(name, type)
      values =
        case type
        when :bool then [t, f]
        end

      @conditions << Condition.new(name, values)
    end

    def table(&block)
      result_table = ResultTable.new([])
      dsl = ResultTableDsl.new(result_table)
      dsl.instance_eval(&block)
      @result_table = result_table
    end
  end

  class ResultTableDsl
    include Values

    def initialize(result_table)
      @result_table = result_table
    end

    def row(conditions, results)
      @result_table.rows << Row.new(conditions, results)
    end
  end
end
