require "../../../spec_helper"

private alias CB = CryBase::CouchBase

describe CB::Policies::RetryPolicy do
  it "is exposed as CouchBase::RetryPolicy" do
    typeof(CB::RetryPolicy.no_retry).should eq(CB::Policies::RetryPolicy)
  end

  it "defaults to no retry" do
    policy = CB::RetryPolicy.no_retry

    policy.max_attempts.should eq(1)
    policy.delay.should eq(0.seconds)
    policy.jitter.should eq(0.0)
    policy.max_elapsed.should be_nil
    policy.retry_query_errors?.should be_true
    policy.retry_transport_errors?.should be_true
    policy.no_retry?.should be_true
  end

  it "accepts explicit retry policy values" do
    policy = CB::RetryPolicy.new(
      max_attempts: 3,
      delay: 25.milliseconds,
      jitter: 0.25,
      max_elapsed: 200.milliseconds,
      retry_query_errors: false,
      retry_transport_errors: true,
    )

    policy.max_attempts.should eq(3)
    policy.delay.should eq(25.milliseconds)
    policy.jitter.should eq(0.25)
    policy.max_elapsed.should eq(200.milliseconds)
    policy.retry_query_errors?.should be_false
    policy.retry_transport_errors?.should be_true
    policy.no_retry?.should be_false
  end

  it "rejects invalid retry budgets" do
    expect_raises(ArgumentError, /max_attempts/) do
      CB::RetryPolicy.new(max_attempts: 0)
    end

    expect_raises(ArgumentError, /delay/) do
      CB::RetryPolicy.new(delay: -1.milliseconds)
    end

    expect_raises(ArgumentError, /jitter/) do
      CB::RetryPolicy.new(jitter: 1.1)
    end

    expect_raises(ArgumentError, /max_elapsed/) do
      CB::RetryPolicy.new(max_elapsed: -1.milliseconds)
    end
  end
end
