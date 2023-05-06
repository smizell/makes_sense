# frozen_string_literal: true

RSpec.describe MakesSense do
  context "#validate" do
    subject { decision_table.validate }

    context "with complete table" do
      let(:decision_table) do
        MakesSense::DecisionTable.define "FizzBuzz" do
          cond :divisible_by_three?, :bool
          cond :divisible_by_five?, :bool

          table do
            row [f, f], :n
            row [t, f], "Fizz"
            row [f, t], "Buzz"
            row [t, t], "FizzBuzz"
          end
        end
      end

      it "returns a success" do
        expect(subject).to be_success
      end
    end

    context "with incomplete table" do
      let(:decision_table) do
        MakesSense::DecisionTable.define "FizzBuzz" do
          cond :divisible_by_three?, :bool
          cond :divisible_by_five?, :bool

          table do
            row [f, f], :n
            row [t, f], "Fizz"
            row [f, t], "Buzz"
          end
        end
      end

      it "returns a validation failure with remaining conditions" do
        expect(subject.failure.length).to be(1)
        expect(subject.failure[0][:expected_conditions]).to eq([true, true])
        expect(subject.failure[0][:expected]).to eq({
          divisible_by_three?: true,
          divisible_by_five?: true
        })
      end
    end

    context "with duplicate rows" do
      context "with a basic table" do
        let(:decision_table) do
          MakesSense::DecisionTable.define "FizzBuzz" do
            cond :cond?, :bool

            table do
              row [f], 1
              row [f], 2
              row [t], 3
            end
          end
        end

        it "returns a failure" do
          expect(subject).to be_failure
        end
      end
    end

    context "with `any` as a value" do
      let(:decision_table) do
        MakesSense::DecisionTable.define "Uses `any`" do
          cond :cond1?, :bool
          cond :cond2?, :bool

          table do
            row [t, any], true
            row [f, any], false
          end
        end
      end

      it "builds the correct rows" do
        expect(subject).to be_success
      end
    end
  end

  context "#execute" do
    let(:decision_table) do
      MakesSense::DecisionTable.define "FizzBuzz" do
        cond :divisible_by_three?, :bool
        cond :divisible_by_five?, :bool

        table do
          row [f, f], ->(n) { n }
          row [t, f], "Fizz"
          row [f, t], "Buzz"
          row [t, t], "FizzBuzz"
        end
      end
    end

    let(:ruleset) { ruleset_class.new }

    subject { decision_table.with_ruleset(ruleset) }

    context "when a valid ruleset" do
      let(:ruleset_class) do
        Class.new do
          def divisible_by_three?(n)
            (n % 3) == 0
          end

          def divisible_by_five?(n)
            (n % 5) == 0
          end
        end
      end

      it "executes the rules" do
        expect(subject.call(n: 1)).to be(1)
        expect(subject.call(n: 3)).to be("Fizz")
        expect(subject.call(n: 5)).to be("Buzz")
        expect(subject.call(n: 15)).to be("FizzBuzz")
      end
    end
  end
end
