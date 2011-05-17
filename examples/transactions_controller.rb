class TransactionsController < ApplicationController
  before_filter :require_valid_transaction

  def confirm
  end

  def abort
    @transaction.abort!
    flash[:notice] = "Transaction aborted."
    redirect_to root_path
  end

  def update
    if @transaction.complete!
      flash[:notice] = "Sucessfully updated your subscription."
    else
      flash[:error] = "Transaction was not successfull, please try again."
    end
    redirect_to root_path
  end

  private

  def require_valid_transaction
    @token = params[:token]
    @subscription = current_user.subscriptions.last
    if @subscription.activated?
      logger.info("Subscription is already activated")
      flash[:notice] = "Subscription is already activated"
      redirect_to root_path
    else
      @transaction = @subscription.transactions.initiated.find_by_identifier(@token)
      unless @transaction
        logger.info("Invalid transaction")
        flash[:error] = "Invalid transaction, please try again."
        redirect_to root_path
      end
    end
  end
end
