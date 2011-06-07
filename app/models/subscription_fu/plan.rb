class SubscriptionFu::Plan
  include ActionView::Helpers::NumberHelper  # for number_to_currency
  include Comparable

  TAX = 0.05

  attr_accessor :key
  attr_accessor :price

  def initialize(key, price, data = {})
    self.key = key
    self.price = price
    data.each {|k,v| self.send("#{k}=", v) }
  end

  def human_name
    I18n.t(key, :scope => [:subscription_fu, :plan, :options])
  end

  def human_price
    number_to_currency(price_with_tax)
  end

  def free_plan?
    price == 0
  end

  def price_with_tax
    (price * (1.0 + TAX)).to_i
  end

  def price_tax
    (price * TAX).to_i
  end

  def currency
    "JPY"
  end

  def <=>(other)
    price <=> other.price
  end
end
