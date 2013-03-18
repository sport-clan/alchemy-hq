Feature: Check site script

  Background:

    Given a config "default":
      """
        <check-site-script base-url="http://hostname:${port}">
          <timings warning="2" critical="4" timeout="10"/>
          <step name="page">
            <request path="/page"/>
            <response/>
          </step>
        </check-site-script>
      """

    Given a config "regex":
      """
        <check-site-script base-url="http://hostname:${port}">
          <timings warning="2" critical="4" timeout="10"/>
          <step name="page">
            <request path="/page"/>
            <response body-regex="y+e+s+"/>
          </step>
        </check-site-script>
      """

    Given a config "timeout":
      """
        <check-site-script base-url="http://hostname:${port}">
          <timings warning="2" critical="4" timeout="0"/>
          <step name="page">
            <request path="/page"/>
            <response/>
          </step>
        </check-site-script>
      """

    Given a config "http-auth":
      """
        <check-site-script base-url="http://hostname:${port}">
          <timings warning="2" critical="4" timeout="10"/>
          <step name="page">
            <request path="/page" username="USER" password="PASS"/>
            <response/>
          </step>
        </check-site-script>
      """

    Given a config "form-auth":
      """
        <check-site-script base-url="http://hostname:${port}">
          <timings warning="2" critical="4" timeout="10"/>
          <step name="login">
            <request path="/login" method="post">
              <param name="username" value="USER"/>
              <param name="password" value="PASS"/>
            </request>
            <response/>
          </step>
          <step name="page">
            <request path="/page" username="USER" password="PASS"/>
            <response/>
          </step>
        </check-site-script>
      """

    Given a config "no-path":
      """
        <check-site-script base-url="http://hostname:${port}/page">
          <timings warning="2" critical="4" timeout="10"/>
          <step name="page">
            <request/>
            <response/>
          </step>
        </check-site-script>
      """

    Given a config "wrong-port":
      """
        <check-site-script base-url="http://hostname:65535">
          <timings warning="2" critical="4" timeout="10"/>
          <step name="page">
            <request path="/path"/>
            <response/>
          </step>
        </check-site-script>
      """

  Scenario: Site responds in ok time
    Given one server which responds in 1 second
     When check-site is run with config "default"
     Then all servers should receive page requests
      And the message should be "Site OK: 1 hosts found, 1.0s time"
      And the status should be 0

  Scenario: Site responds in warning time
    Given one server which responds in 1 second
      And one server which responds in 3 seconds
     When check-site is run with config "default"
     Then all servers should receive page requests
      And the message should be "Site WARNING: 2 hosts found, 3.0s time (warning is 2.0)"
      And the status should be 1

  Scenario: Site responds in critical time
    Given one server which responds in 1 second
      And one server which responds in 3 seconds
      And one server which responds in 5 seconds
     When check-site is run with config "default"
     Then all servers should receive page requests
      And the message should be "Site CRITICAL: 3 hosts found, 5.0s time (critical is 4.0)"
      And the status should be 2

  Scenario: Body contains regex
    Given one server which responds with "-yes-"
     When check-site is run with config "regex"
     Then all servers should receive page requests
      And the message should be "Site OK: 1 hosts found, 0.0s time"
      And the status should be 0

  Scenario: Body does not contain regex
    Given one server which responds with "-yes-"
      And one server which responds with "-no-"
     When check-site is run with config "regex"
     Then all servers should receive page requests
      And the message should be "Site CRITICAL: 2 hosts found, 1 mismatches, 0.0s time"
      And the status should be 2

  Scenario: Timeout does not expire
    Given one server which responds in 0 seconds
     When check-site is run with config "default"
     Then all servers should receive page requests
      And the message should be "Site OK: 1 hosts found, 0.0s time"
      And the status should be 0

  Scenario: Timeout expires
    Given one server which responds in 0 seconds
     When check-site is run with config "timeout"
      And the message should be "Site CRITICAL: 1 hosts found, 1 uncontactable"
      And the status should be 2

  Scenario: Username and password are correct
    Given one server which requires username "USER" and password "PASS"
     When check-site is run with config "http-auth"
     Then all servers should receive page requests
      And the message should be "Site OK: 1 hosts found, 0.0s time"
      And the status should be 0

  Scenario: Username and password are incorrect
    Given one server which requires username "USER" and password "SECRET"
     When check-site is run with config "http-auth"
     Then all servers should receive page requests
      And the message should be "Site CRITICAL: 1 hosts found, 1 errors (401), 0.0s time"
      And the status should be 2

  Scenario: No servers
     When check-site is run with config "default"
      And the message should be "Site CRITICAL: unable to resolve hostname"
      And the status should be 2

  Scenario: Form based login
    Given one server which requires form based login with "USER" and "PASS"
     When check-site is run with config "form-auth"
     Then all servers should receive page requests
      And the message should be "Site OK: 1 hosts found, 0.0s time"
      And the status should be 0

  Scenario: No path specified
    Given one server which responds in 0 seconds
     When check-site is run with config "no-path"
     Then all servers should receive page requests
      And the message should be "Site OK: 1 hosts found, 0.0s time"
      And the status should be 0

  Scenario: Connection refused
    Given one server which responds in 0 seconds
     When check-site is run with config "wrong-port"
     Then the message should be "Site CRITICAL: 1 hosts found, 1 uncontactable"
      And the status should be 2
