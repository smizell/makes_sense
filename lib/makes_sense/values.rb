module MakesSense
  module Values
    def t
      true
    end

    def f
      false
    end

    class Any; end

    def any
      Any.new
    end
  end
end
