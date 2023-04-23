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

      it "build the correct rows" do
        expect(subject).to be_success
      end
    end
  end
end
