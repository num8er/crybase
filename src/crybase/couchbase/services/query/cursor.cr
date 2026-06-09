# Single-use streaming cursor returned by `Query::Client#query_cursor` and
# `Query::Cluster#query_cursor`.
#
# The HTTP request starts when `each` or `each_as` is called. Rows are yielded as
# they are parsed from the Query response body, and the final `Result` is stored
# in `result` after the cursor is fully consumed.
class CryBase::CouchBase::Services::Query::Cursor
  getter result : Result?

  @closed : Bool
  @mutex : Mutex
  @runner : Proc(Proc(JSON::Any, Nil), Result)
  @started : Bool

  # :nodoc:
  def initialize(@runner : Proc(Proc(JSON::Any, Nil), Result))
    @closed = false
    @mutex = Mutex.new
    @result = nil
    @started = false
  end

  # :nodoc:
  def initialize(&@runner : Proc(Proc(JSON::Any, Nil), Result))
    @closed = false
    @mutex = Mutex.new
    @result = nil
    @started = false
  end

  def each(&block : JSON::Any ->) : Result
    start!

    result = @runner.call(->(row : JSON::Any) do
      raise IO::Error.new("Query cursor is closed") if closed?

      block.call(row)
    end)
    finish(result)
    result
  rescue ex
    close
    raise ex
  end

  def each_as(type : T.class, &block : T ->) : Result forall T
    each do |row|
      block.call(T.from_json(row.to_json))
    end
  end

  def close : Nil
    @mutex.synchronize { @closed = true }
  end

  def closed? : Bool
    @mutex.synchronize { @closed }
  end

  private def start! : Nil
    @mutex.synchronize do
      raise IO::Error.new("Query cursor has already been consumed") if @started
      raise IO::Error.new("Query cursor is closed") if @closed

      @started = true
    end
  end

  private def finish(result : Result) : Nil
    @mutex.synchronize do
      @result = result
      @closed = true
    end
  end
end
