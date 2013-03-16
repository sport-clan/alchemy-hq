Feature: Check site script

  Background:
    Given a warning time of 2 seconds
      And a critical time of 4 seconds

  Scenario: Site responds in ok time
    Given that one server responds in 1 second
     When check-site is run
     Then the status should be 0
      And the message should be "Site OK: 1 hosts found, 1.0s time"

  Scenario: Site responds in warning time
    Given that one server responds in 1 second
      And another server responds in 3 seconds
     When check-site is run
     Then the status should be 1
      And the message should be "Site WARNING: 2 hosts found, 3.0s time (warning is 2.0)"

  Scenario: Site responds in critical time
    Given that one server responds in 1 second
      And another server responds in 3 seconds
      And another server responds in 5 seconds
     When check-site is run
     Then the status should be 2
      And the message should be "Site CRITICAL: 3 hosts found, 5.0s time (critical is 4.0)"
