require_relative "result"
require_relative "values"

module MakesSense
  Condition = Struct.new(:name, :values)
  ResultTable = Struct.new(:rows)
  Row = Struct.new(:conditions, :results)

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
      result_possibilities = expanded_rows.map(&:conditions)

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

    def expanded_rows
      new_rows = []

      @result_table.rows.each do |row|
        has_any = row.conditions.any? { |condition| condition.is_a?(Values::Any) }

        unless has_any
          new_rows << row
          next
        end

        collected = []
        current = []

        row.conditions.each_with_index do |condition, index|
          case condition
          when Values::Any
            collected << current
            collected << @conditions[index].values
            current = []
          else
            current << condition
          end
        end

        collected << current unless current.empty?

        new_conditions = collected.reduce { |a, b| a.product(b) }

        new_conditions.each do |conditions|
          new_rows << Row.new(conditions, row.results)
        end
      end

      new_rows
    end
  end

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
