module Contror
  module ObjectTry
    refine ::Object do
      def try
        if self != nil
          yield self
        end
      end

      def continue
        yield self
      end
    end
  end
end
