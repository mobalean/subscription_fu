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
    @transaction = current_group.pending_transaction(@token)
    unless @transaction
      logger.info("Invalid transaction for token: #{@token}")
      flash[:error] = "Invalid transaction, please try again."
      redirect_to root_path
    end
  end
end
