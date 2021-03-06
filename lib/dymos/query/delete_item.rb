module Dymos
  module Query
    class DeleteItem < Base
      def command
        'delete_item'
      end

      def key(value)
        @query[:key] = value.deep_stringify_keys
        self
      end

      def expected(value)
        value.map { |v| add_expected(*v) }
        self
      end

      def add_expected(*values)
        column, operator, value = parse_condition(*values)
        @query[:expected] ||= {}
        @query[:expected].store(*_add_expected(column, operator, value))
        self
      end

      def _add_expected(column, operator, value)
        [column.to_s, {
                      attribute_value_list: ([:BETWEEN, :IN].include? operator) ? [*value] : [value],
                      comparison_operator: operator.to_s.upcase
                    }
        ]
      end

      def conditional_operator(value)
        @query[:conditional_operator] = value.to_s.upcase
        self
      end


      def return_values(value)
        @query[:return_values] = value.to_s.upcase
        self
      end

      def return_consumed_capacity(value)
        @query[:return_consumed_capacity] = value.to_s.upcase
        self
      end

      def return_item_collection_metrics(value)
        @query[:return_item_collection_metrics] = value.to_s.upcase
        self
      end

      def condition_expression(value)
        @query[:condition_expression] = value
        self
      end

      def expression_attribute_names(value)
        @query[:expression_attribute_names] = value.deep_stringify_keys
        self
      end

      def expression_attribute_values(value)
        @query[:expression_attribute_values] = value.deep_stringify_keys
        self
      end

    end
  end
end