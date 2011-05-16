Factory.sequence(:initiator_email) {|n| "mail#{n}@mobalean.com"}
Factory.define(:initiator) do |a|
  a.email {|o| Factory.next(:initiator_email) }
end
