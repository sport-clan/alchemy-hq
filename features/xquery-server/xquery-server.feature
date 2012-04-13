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
