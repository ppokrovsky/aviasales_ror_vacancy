# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :flight do
    origin_iata "MyString"
    destination_iata "MyString"
    departure "2012-03-18 12:06:58"
    arrival "2012-03-18 12:06:58"
    price "9.99"
  end
end
