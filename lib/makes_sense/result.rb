module MakesSense
  class Success
    attr_reader :value

    def initialize(value)
      @value = value
    end

    def success?
      true
    end

    def failure?
      false
    end

    def value!
      @value
    end

    def failure
      raise "Not a failure"
    end
  end

  class Failure
    def initialize(value)
      @value = value
    end

    def success?
      false
    end

    def failure?
      true
    end

    def value!
      raise "Not successful"
    end

    def failure
      @value
    end
  end
end
