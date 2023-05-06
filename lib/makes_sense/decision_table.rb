require_relative "result"
require_relative "values"

module MakesSense
  Condition = Struct.new(:name, :values)
  ResultTable = Struct.new(:rows)
  Row = Struct.new(:conditions, :results, :row_index)

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
      condition_values = @conditions.map(&:values)
      possible_conditions = condition_values[0].product(*condition_values[1..])
      expanded_rows = expand_rows
      expanded_row_conditions = expanded_rows.map(&:conditions)

      errors = []

      possible_conditions.each do |possible_condition|
        unless expanded_row_conditions.include?(possible_condition)
          errors << {
            type: :missing,
            message: "Missing result condition: #{possible_condition}",
            expected_conditions: possible_condition,
            expected: {}.tap do |condition_map|
              @conditions.each_with_index do |condition, index|
                condition_map[condition.name] = possible_condition[index]
              end
            end
          }
        end
      end

      visited = []

      expanded_rows.each do |row|
        found_index = visited.find_index(row.conditions)
        if found_index
          errors << {
            type: :duplicate,
            message: "Duplicate result #{row.conditions} for rows #{found_index} and #{row.row_index}",
            row: row,
            duplicate_index: found_index
          }
        end

        visited << row.conditions
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

      @result_table.rows.each_with_index do |row, row_index|
        needs_expansion = row.conditions.any? { |condition| condition.is_a?(Values::Any) }

        unless needs_expansion
          new_rows << row
          next
        end

        collected = []
        current = []

        row.conditions.each_with_index do |condition, index|
          case condition
          when Values::Any
            unless current.empty?
              collected << current
              current = []
            end

            collected << @conditions[index].values
          else
            current << condition
          end
        end

        collected << current unless current.empty?

        # When the `collected` length is `1`, it results in unexpected values with `#reduce`
        # Checking for the length and only reducing when it's greater than one causes the
        # resulting value to be as expected.
        new_conditions =
          if collected.length > 1
            collected.reduce { |a, b| a.product(b) }
          else
            collected[0].map { |v| [v] }
          end

        new_conditions.each do |conditions|
          new_rows << Row.new(conditions, row.results, row_index)
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
      @result_table.rows << Row.new(conditions, results, @result_table.rows.length)
    end
  end
end
