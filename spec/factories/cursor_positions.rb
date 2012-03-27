# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :cursor_position do
    session_id 1
    x 1.5
    y 1.5
  end
end
