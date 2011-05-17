class SubscriptionsController < ApplicationController
  def new
  end

  def create
    @subscription = current_group.build_next_subscription("basic")
    @subscription.save!
    @transaction = @subscription.initiate_activation(current_user)
    redirect_to @transaction.start_checkout(url_for(:action => :confirm, :controller => "transactions"), url_for(:action => :abort, :controller => "transactions"))
  end
 
end
