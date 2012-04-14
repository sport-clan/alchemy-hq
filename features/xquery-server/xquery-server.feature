Feature: XQuery server

  Scenario: Perform a transform

    Given an xquery script:
      """
      1 + 1
      """

    And an input document:
      """
      <xml/>
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
