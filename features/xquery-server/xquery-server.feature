Feature: XQuery server

  Scenario: Perform a transform

	When I compile the query:
      """
      1 + 1
      """

	And I run the query

    Then the result should be:
      """
      2
      """

  Scenario: Reference the source document

	When I compile the query:
      """
      string (/doc/elem/@attr)
      """

    And I run the query against:
      """
      <doc>
        <elem attr="hello world"/>
      </doc>
      """

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

    When I compile the query:
      """
      import module namespace lib = "module.xquery";
      string-join (lib:message (), ', ')
      """

    And I run the query

    Then the result should be:
      """
      hello world 1, hello world 2
      """

  Scenario: Call a function

	When I compile the query:
      """
      declare namespace hq = "hq";
      declare function hq:test () as xs:string external;
      hq:test ()
      """

    And I run the query against:
      """
      <doc/>
      """

    Then the result should be:
      """
      hello world
      """

  Scenario: Invalid xquery

    When I compile the query:
      """
      123;;;
      """

    And I run the query

    Then I should get an error
