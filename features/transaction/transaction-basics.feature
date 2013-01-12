Feature: Basic transaction management
  In order to allow concurrent use
  As an end user
  I want to use transactions to interact with the system

  Scenario: Begin transaction
    When I call transaction_begin
    Then a transaction id is returned
    And a transaction is begun

  Scenario: Commit transaction
    Given that I have begun a transaction
    When I call transaction_commit
    Then the transaction is committed

  Scenario: Rollback transaction
    Given that I have begun a transaction
    When I call transaction_rollback
    Then the transaction is rolled back
