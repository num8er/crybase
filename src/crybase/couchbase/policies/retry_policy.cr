struct CryBase::CouchBase::Policies::RetryPolicy
  getter max_attempts : Int32
  getter delay : Time::Span
  getter jitter : Float64
  getter max_elapsed : Time::Span?
  getter? retry_query_errors : Bool
  getter? retry_transport_errors : Bool

  def self.no_retry : RetryPolicy
    new
  end

  def initialize(
    @max_attempts : Int32 = 1,
    @delay : Time::Span = 0.seconds,
    @jitter : Float64 = 0.0,
    @max_elapsed : Time::Span? = nil,
    *,
    @retry_query_errors : Bool = true,
    @retry_transport_errors : Bool = true,
  )
    raise ArgumentError.new("retry max_attempts must be at least 1") if @max_attempts < 1
    raise ArgumentError.new("retry delay cannot be negative") if @delay < 0.seconds
    raise ArgumentError.new("retry jitter must be between 0.0 and 1.0") if @jitter < 0.0 || @jitter > 1.0
    if max_elapsed = @max_elapsed
      raise ArgumentError.new("retry max_elapsed cannot be negative") if max_elapsed < 0.seconds
    end
  end

  def no_retry? : Bool
    @max_attempts == 1
  end
end
