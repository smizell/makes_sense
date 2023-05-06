require_relative "result"
require_relative "values"

module MakesSense
  Condition = Struct.new(:name, :values)
  ResultTable = Struct.new(:rows)
  Row = Struct.new(:conditions, :results)

  class DecisionTable
    def initialize(name, conditions, result_table, args)
      @name = name
      @conditions = conditions
      @result_table = result_table
      @args = args
    end

    def self.define(name, &block)
      dsl = DecisionTableDsl.new
      dsl.instance_eval(&block)
      new(name, dsl.conditions, dsl.result_table, dsl.args)
    end

    def validate
      cond_values = @conditions.map(&:values)
      cond_possibilities = cond_values[0].product(*cond_values[1..])
      result_possibilities = expand_rows.map(&:conditions)

      errors = []

      cond_possibilities.each do |cond_possibility|
        unless result_possibilities.include?(cond_possibility)
          errors << {
            type: :missing,
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

      visited = []

      result_possibilities.each do |result_possibility|
        if visited.include?(result_possibility)
          errors << {
            type: :duplicate,
            message: "Duplicate result: #{result_possibility}",
            result: result_possibility
          }
        end

        visited << result_possibility
      end

      if !errors.empty?
        Failure.new(errors)
      else
        Success.new(self)
      end
    end

    def with_ruleset(ruleset)
      ->(**kwargs) do
        expanded_rows = expand_rows

        ruleset_results = @conditions.map do |condition|
          method_kwarg_names = ruleset.method(condition.name).parameters.map { |parameter| parameter[1] }
          args = method_kwarg_names.map { |kwarg_name| kwargs[kwarg_name] }
          ruleset.public_send(condition.name, *args)
        end

        result_row = @result_table.rows.find do |row|
          row.conditions == ruleset_results
        end

        if result_row.results.respond_to?(:call)
          method_kwarg_names = result_row.results.parameters.map { |parameter| parameter[1] }
          args = method_kwarg_names.map { |kwarg_name| kwargs[kwarg_name] }
          result_row.results.call(*args)
        else
          result_row.results
        end
      end
    end

    private

    # TODO: needs to be pulled out of this class
    def expand_rows
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
            collected << current unless current.empty?
            collected << @conditions[index].values
            current = []
          else
            current << condition
          end
        end

        collected << current unless current.empty?

        new_conditions =
          if collected.length > 1
            collected.reduce { |a, b| a.product(b) }
          else
            collected[0].map { |v| [v] }
          end

        new_conditions.each do |conditions|
          new_rows << Row.new(conditions, row.results)
        end
      end

      new_rows
    end
  end

  class DecisionTableDsl
    include Values

    attr_reader :args, :conditions, :result_table

    def initialize
      @args = []
      @conditions = []
      @result_table = nil
    end

    def arg(name)
      @args << name
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
