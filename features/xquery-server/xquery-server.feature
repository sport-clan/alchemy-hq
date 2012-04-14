Feature: XQuery server

  Scenario: Perform a transform

    Given an xquery script:
      """
      1 + 1
      """

    When I perform the transform

    Then the result should be:
      """
      2
      """

  Scenario: Reference the source document

    Given an xquery script:
      """
      string (/doc/elem/@attr)
      """

    And an input document:
      """
      <doc>
        <elem attr="hello world"/>
      </doc>
      """

    When I perform the transform

    Then the result should be:
      """
      hello world
      """

  Scenario: Import a module

    Given an xquery module named "module.xquery":
      """
      module namespace lib = "module.xquery";
      declare function lib:message () as item () * {
        ("hello world 1", "hello world 2")
      };
      """

    And an xquery script:
      """
      import module namespace lib = "module.xquery";
      string-join (lib:message (), ', ')
      """

    When I perform the transform

    Then the result should be:
      """
      hello world 1, hello world 2
      """

  Scenario: Invalid xquery

    Given an xquery script:
      """
      123;;;
      """

    When I perform the transform

    Then I should get an error
