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

  Scenario: Get by id parts

	When I compile the query:
      """
      declare namespace hq = "hq";
      declare function hq:get (
          $type as xs:string,
          $id-parts as xs:string *
        ) as element () external;
      hq:get ('a', ('b', 'c'))
      """

    And I run the query against:
      """
      <doc/>
      """

    Then the result should be:
      """
      <get-record-by-id-parts type="a">
        <part value="b"/>
        <part value="c"/>
      </get-record-by-id-parts>
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
