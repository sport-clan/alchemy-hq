Feature: Check site script

  Background:

    Given a config "default":
      """
        <check-site-script base-url="${base-url}">
          <timings warning="2" critical="4" timeout="10"/>
          <step name="page">
            <request path="/page"/>
            <response/>
          </step>
        </check-site-script>
      """

    Given a config "regex":
      """
        <check-site-script base-url="${base-url}">
          <timings warning="2" critical="4" timeout="10"/>
          <step name="page">
            <request path="/page"/>
            <response body-regex="y+e+s+"/>
          </step>
        </check-site-script>
      """

    Given a config "timeout":
      """
        <check-site-script base-url="${base-url}">
          <timings warning="2" critical="4" timeout="0"/>
          <step name="page">
            <request path="/page"/>
            <response/>
          </step>
        </check-site-script>
      """

    Given a config "http-auth":
      """
        <check-site-script base-url="${base-url}">
          <timings warning="2" critical="4" timeout="10"/>
          <step name="page">
            <request path="/page" username="USER" password="PASS"/>
            <response/>
          </step>
        </check-site-script>
      """

  Scenario: Site responds in ok time
    Given one server which responds in 1 second
     When check-site is run with config "default"
     Then the message should be "Site OK: 1 hosts found, 1.0s time"
      And the status should be 0

  Scenario: Site responds in warning time
    Given one server which responds in 1 second
      And another server which responds in 3 seconds
     When check-site is run with config "default"
     Then the message should be "Site WARNING: 2 hosts found, 3.0s time (warning is 2.0)"
      And the status should be 1

  Scenario: Site responds in critical time
    Given one server which responds in 1 second
      And another server which responds in 3 seconds
      And another server which responds in 5 seconds
     When check-site is run with config "default"
     Then the message should be "Site CRITICAL: 3 hosts found, 5.0s time (critical is 4.0)"
      And the status should be 2

  Scenario: Body contains regex
    Given one server which responds with "-yes-"
     When check-site is run with config "regex"
     Then the message should be "Site OK: 1 hosts found, 0.0s time"
      And the status should be 0

  Scenario: Body does not contain regex
    Given one server which responds with "-yes-"
      And another server which responds with "-no-"
     When check-site is run with config "regex"
     Then the message should be "Site CRITICAL: 2 hosts found, 1 mismatches, 0.0s time"
      And the status should be 2

  Scenario: Timeout does not expire
    Given one server which responds in 0 seconds
     When check-site is run with config "default"
     Then the message should be "Site OK: 1 hosts found, 0.0s time"
      And the status should be 0

  Scenario: Timeout expires
    Given one server which responds in 0 seconds
     When check-site is run with config "timeout"
     Then the message should be "Site CRITICAL: 1 hosts found, 1 uncontactable"
      And the status should be 2

  Scenario: Username and password are correct
    Given one server which requires username "USER" and password "PASS"
     When check-site is run with config "http-auth"
     Then the message should be "Site OK: 1 hosts found, 0.0s time"
      And the status should be 0

  Scenario: Username and password are incorrect
    Given one server which requires username "USER" and password "SECRET"
     When check-site is run with config "http-auth"
     Then the message should be "Site CRITICAL: 1 hosts found, 1 errors (401), 0.0s time"
      And the status should be 2

  Scenario: No servers
     When check-site is run with config "default"
     Then the message should be "Site CRITICAL: unable to resolve hostname"
      And the status should be 2
