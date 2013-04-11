Feature: Callback functions

  Scenario: Get by id

	When I compile the query:
      """
      declare namespace hq = "hq";
      declare function hq:get (
          $id as xs:string
        ) as element () external;
      hq:get ('a')
      """

    And I run the query against:
      """
      <doc/>
      """

    Then the result should be:
      """
      <get-record-by-id id="a"/>
      """

  Scenario: Find

	When I compile the query:
      """
      declare namespace hq = "hq";
      declare function hq:find (
          $type as xs:string
        ) as element () external;
      hq:find ('a')
      """

    And I run the query against:
      """
      <doc/>
      """

    Then the result should be:
      """
      <search-records type="a"/>
      """
