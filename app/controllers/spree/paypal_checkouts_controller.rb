module Spree
  class PaypalCheckoutsController < StoreController

    skip_before_action :verify_authenticity_token, only: [:create, :confirm]

    def create
      @order = Spree::Order.friendly.find params[:order_id]
      @payment_method = PaymentMethod.find(params[:payment_method_id])
      @paypal_payment = @payment_method.request_payment(@order)
      if @paypal_payment.create
        render json: { paymentID: @paypal_payment.id }
      else
        render status: 500, json: { error: @paypal_payment.error }
      end
    end

    def confirm
      @order = Spree::Order.friendly.find params[:order_id]

      paypal_checkout = Spree::PaypalCheckout.new(
        payer_id: params[:payerID],
        payment_id: params[:paymentID]
      )

      @order.payments.create!({
        source: paypal_checkout,
        amount: @order.total,
        payment_method_id: params[:payment_method_id]
      })

      until @order.state == "complete"
        if @order.next!
          @order.update_with_updater!
        else
          render status: 500, json: { error: @order.errors.full_messages.join(', ') }
        end
      end

      flash.now['order_completed'] = true
      render json: { path: completion_route }
    end

    private

    def completion_route(custom_params = nil)
      spree.order_path(@order, custom_params)
    end
  end
end