Feature: Check site script

  Background:
    Given a warning time of 2 seconds
      And a critical time of 4 seconds

  Scenario: Site responds in ok time
    Given one server which responds in 1 second
     When check-site is run
     Then the status should be 0
      And the message should be "Site OK: 1 hosts found, 1.0s time"

  Scenario: Site responds in warning time
    Given one server which responds in 1 second
      And another server which responds in 3 seconds
     When check-site is run
     Then the status should be 1
      And the message should be "Site WARNING: 2 hosts found, 3.0s time (warning is 2.0)"

  Scenario: Site responds in critical time
    Given one server which responds in 1 second
      And another server which responds in 3 seconds
      And another server which responds in 5 seconds
     When check-site is run
     Then the status should be 2
      And the message should be "Site CRITICAL: 3 hosts found, 5.0s time (critical is 4.0)"

  Scenario: Body contains regex
    Given a regex of "y+e+s+"
      And one server which responds with "-yes-"
     When check-site is run
     Then the status should be 0
     And the message should be "Site OK: 1 hosts found, 0.0s time"

  Scenario: Body does not contain regex
    Given a regex of "y+e+s+"
      And one server which responds with "-yes-"
      And another server which responds with "-no-"
     When check-site is run
     Then the status should be 2
     And the message should be "Site CRITICAL: 2 hosts found, 1 mismatches, 0.0s time"

  Scenario: Timeout does not expire
    Given a timeout of 10 seconds
      And one server which responds in 0 seconds
     When check-site is run
     Then the status should be 0
      And the message should be "Site OK: 1 hosts found, 0.0s time"

  Scenario: Timeout expires
    Given a timeout of 0 seconds
      And one server which responds in 0 seconds
     When check-site is run
     Then the status should be 2
      And the message should be "Site CRITICAL: 1 hosts found, 1 uncontactable"

  Scenario: Username and password are correct
    Given a username of "USER"
      And a password of "PASS"
      And one server which requires username "USER" and password "PASS"
     When check-site is run
     Then the status should be 0
      And the message should be "Site OK: 1 hosts found, 0.0s time"

  Scenario: Username and password are incorrect
    Given a username of "USER"
      And a password of "PASS"
      And one server which requires username "USER" and password "SECRET"
     When check-site is run
     Then the status should be 2
      And the message should be "Site CRITICAL: 1 hosts found, 1 errors (401), 0.0s time"
