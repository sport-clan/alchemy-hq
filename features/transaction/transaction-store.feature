Feature: Store data
  In order to express my intentions
  As an end user
  I want to store data in the database

  Scenario: Store data updates transaction
    Given that I have begun a transaction
    When I call data_store
    Then the record is stored in the transaction
