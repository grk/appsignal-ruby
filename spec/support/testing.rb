module Appsignal
  class << self
    remove_method :testing?

    # @api private
    def testing?
      true
    end
  end

  # @api private
  module Testing
    class << self
      def transactions
        @transactions ||= []
      end

      def clear!
        transactions.clear
      end

      attr_writer :keep_transactions
      # @see TransactionHelpers#keep_transactions
      def keep_transactions?
        defined?(@keep_transactions) ? @keep_transactions : nil
      end

      attr_writer :sample_transactions
      # @see TransactionHelpers#keep_transactions
      def sample_transactions?
        sample = defined?(@sample_transactions) ? @sample_transactions : nil
        if sample.nil?
          keep_transactions?
        else
          @sample_transactions
        end
      end
    end
  end

  class Transaction
    class << self
      alias original_new new

      # Override the {Appsignal::Transaction.new} method so we can track which
      # transactions are created on the {Appsignal::Testing.transactions} list.
      #
      # @see TransactionHelpers#last_transaction
      def new(*args)
        transaction = original_new(*args)
        Appsignal::Testing.transactions << transaction
        transaction
      end
    end
  end

  class Extension
    class Transaction
      alias original_finish finish if respond_to? :finish

      # Override default {Extension::Transaction#finish} behavior to always
      # return true, which tells the transaction to add its sample data (unless
      # used in combination with {TransactionHelpers#keep_transactions}
      # `:sample => false`). This allows us to use
      # {Appsignal::Transaction#to_h} without relying on the extension sampling
      # behavior.
      #
      # @see TransactionHelpers#keep_transactions
      def finish(*args)
        return_value = original_finish(*args)
        return_value = true if Appsignal::Testing.sample_transactions?
        return_value
      end

      alias original_complete complete if respond_to? :complete

      # Override default {Extension::Transaction#complete} behavior to
      # store the transaction JSON before the transaction is completed
      # and it's no longer possible to request the transaction JSON.
      #
      # @see TransactionHelpers#keep_transactions
      # @see #_completed?
      def complete
        @completed = true # see {#_completed?} method
        @transaction_json = to_json if Appsignal::Testing.keep_transactions?
        original_complete
      end

      # Returns true when the Transaction was completed.
      # {Appsignal::Extension::Transaction.complete} was called.
      #
      # @return [Boolean] returns if the transaction was completed.
      def _completed?
        @completed || false
      end

      alias original_to_json to_json

      # Override default {Extension::Transaction#to_json} behavior to
      # return the stored the transaction JSON when the transaction was
      # completed.
      #
      # @see TransactionHelpers#keep_transactions
      def to_json
        if defined? @transaction_json
          @transaction_json
        else
          original_to_json
        end
      end
    end
  end
end
