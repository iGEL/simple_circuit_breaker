class SimpleCircuitBreaker
  VERSION = '0.2.1'

  class CircuitOpenError < StandardError
  end

  attr_reader :failure_threshold, :retry_timeout

  def initialize(failure_threshold=3, retry_timeout=10, store = nil)
    @failure_threshold = failure_threshold
    @retry_timeout = retry_timeout
    @store = store
    reset!
  end

  def handle(*exceptions, &block)
    if tripped?
      raise CircuitOpenError, 'Circuit is open'
    else
      execute(exceptions, &block)
    end
  end

  def set_callback(callback)
    @callback = callback
  end

private

  def execute(exceptions, &block)
    begin
      yield.tap { reset! }
    rescue Exception => exception
      if exceptions.empty? || exceptions.include?(exception.class)
        fail!
      end
      raise
    end
  end

  def fail!
    store.record_failure
    trip! if store.failures >= @failure_threshold
  end

  def trip!
    notify_callback(:open)
    store.state = :open
    store.open_time = Time.now
  end

  def reset!
    notify_callback(:closed)
    store.state = :closed
    store.failures = 0
  end

  def tripped?
    store.state == :open && !timeout_exceeded?
  end

  def timeout_exceeded?
    store.open_time + @retry_timeout < Time.now
  end

  def callback
    @callback || -> (*) {}
  end

  def notify_callback(new_state)
    callback.call(new_state) if store.state && store.state != new_state
  end

  def store
    @store ||= MemoryStore.new
  end

  class MemoryStore
    attr_accessor :state, :open_time, :failures

    def record_failure
      @failures += 1
    end
  end
end
