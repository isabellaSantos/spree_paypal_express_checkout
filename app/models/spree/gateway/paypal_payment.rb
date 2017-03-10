module Spree
  module Gateway::PaypalPayment

    def payment(order, web_profile_id)
      payment_options = payment_payload(order, web_profile_id)
      @payment = PayPal::SDK::REST::DataTypes::Payment.new(payment_options)
      return @payment
    end

    def payment_payload(order, web_profile_id)
      order_subtotal = order.item_total + order.promo_total
      payload = {
        intent: 'sale',
        experience_profile_id: web_profile_id,
        payer:{
          payment_method: 'paypal',
          payer_info:{
            first_name: order.billing_address.first_name,
            last_name: order.billing_address.last_name,
            email: order.email,
            billing_address: billing_address(order)
          }
        },
        redirect_urls: {
          return_url: store_url(order), # Store.current.url + Core::Engine.routes.url_helpers.paypal_express_return_order_checkout_path(order.id),
          cancel_url: store_url(order)  # Store.current.url + Core::Engine.routes.url_helpers.paypal_express_cancel_order_checkout_path(order.id),
        },
        transactions:[{
          item_list:{
            items: order_line_items(order)
          },
          amount: {
            total: order.total.to_s,
            currency: order.currency,
            details:{
              shipping: order.shipments.map(&:discounted_cost).sum,
              subtotal: order_subtotal.to_s,
              tax: order.additional_tax_total.to_s
            }
          },
          description: 'This is the sale description',
        }]
      }
    end

    def order_line_items(order)
      items = []

      order.line_items.map do |item|
        items << {
          name: item.product.name,
          sku: item.product.sku,
          price: item.price.to_s,
          currency: item.order.currency,
          quantity: item.quantity
        }
      end

      order.all_adjustments.eligible.each do |adj|
        next if adj.amount.zero?
        next if adj.source_type.eql?('Spree::TaxRate')
        next if adj.source_type.eql?('Spree::Shipment')

        items << {
          name: adj.label,
          price: adj.amount.to_s,
          currency: order.currency,
          quantity: 1
        }
      end
      items
    end

    def billing_address(order)
      state_name = order.billing_address.state.present? ? order.billing_address.state.name : order.billing_address.state_name
      {
        recipient_name: order.billing_address.full_name,
        line1: "#{order.billing_address.address1} #{order.billing_address.address2}",
        city: order.billing_address.city,
        country_code: order.billing_address.country.iso,
        postal_code: order.billing_address.zipcode,
        phone: order.billing_address.phone,
        state: state_name
      }
    end

    def store_url(order)
      Store.current.url
    end

  end
end
