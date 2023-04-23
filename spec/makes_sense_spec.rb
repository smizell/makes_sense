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
        expect(subject.failure[0][:expected_conditions]).to eq([true, true])
        expect(subject.failure[0][:expected]).to eq({
          divisible_by_three?: true,
          divisible_by_five?: true
        })
      end
    end
  end
end
