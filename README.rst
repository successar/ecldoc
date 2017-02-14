ECLDoc

This document and the associated test and output files provide a specification for a project
to build a documentation generation system for ECL, analogous to the JAVADOC system for
JAVA and the pydoc system for Python.

OBJECTIVE:
- Provide a facility that can be launched from a command-line or IDE that will format 
  documentation from docstring information contained in ECL source files.
- Ability to produce above documentation in several formats including plain text and HTML.

SUCCESS CRITERIA:
- Provide an ecldoc executable that can: 
  - Convert each of the ecl files in the ECLSamples folder to substantially match each of the
    corresponding text and HTML documents in the TextOut and HTMLOut folders.
- Allows input files (ecl source files) to be specified as a single file or wildcarded path specification
- Optionally provides a 'recursive' option that will convert all ecl files within a nested folder
  structure.
- Allows the specification of the output format (text or html) and output location

PROJECT DETAILS

Multiple levels of documentation may be used within an ECL source file.  For example:
- Module level
- Sub-module level
- Attribute level
- Sub-attribute level

A minimum of five nested levels will be tested, thought the code should be designed to allow N levels.
Formatting may not be elegant when more than five levels of hierarchy are used.

Hierarchy is established by examining the ECL code for hierarchical start / end markers.
Encountering a start or end marker outside of an ECL comment will cause a hierarchy level to be incremented
or decremented.

Specific start markers include:
- MODULE
- RECORD
- TRANSFORM
- FUNCTION
- INTERFACE
- TYPE
- MACRO

End markers include:
- END
- ENDMACRO

Note: The parser must eliminate any commented strings using either form of comment ('//' and '/* ... */'), and should 
identify start and end markers only when they are separated by whitespace characters or any of the following 
special characters: ':=;,><.!+-/'.  For example:  'ENDMACRO' should not be seen as an End Marker, but 'END;' should be.

Docstrings are recognized as follows:
- Any ECL comment enclosed by "/**" ... "*/" that occurs:
  - Directly preceding a line beginning with EXPORT.  All whitespace including newlines are ignored.

The general approach to formatting is as follows:

<docstring-type>: <attribute-signature>

  <contents>
  
For each increase in hierarchy level, an additional indent is added before each section

<docstring-type> is inferred by scanning the EXPORT line from ":=" (to the first ';' regardless of newlines)
  for one of the following tokens:
  - Any start marker (above)
  - BEGINC++, IMPORT, EMBED, MACRO, FUNCTIONMACRO
  If one is found, then that token will be mapped to docstring-type as follows:
  - MODULE -> MODULE
  - RECORD -> RECORD
  - TRANSFORM -> TRANSFORM
  - INTERFACE -> INTERFACE
  - TYPE -> TYPE
  - BEGINC++ -> FUNCTION
  - IMPORT -> FUNCTION
  - EMBED -> FUNCTION
  - MACRO -> MACRO
  - FUNCTIONMACRO -> FUNCTION MACRO
  Anything else is either mapped to ATTRIBUTE or FUNCTION.  If there are open and close parentheses ("()")
  between the EXPORT and the ":=" token, then it is mapped as FUNCTION, otherwise ATTRIBUTE.
  
The <attribute-signature> is obtained by scanning from the EXPORT until the ':=' token and stripping any leading
or trailing whitespace.
  
<content> is the remainder of the comment with the following modifications:
- Any leading asterisks ('*') are removed
- Tokens (words separated by whitespace or punctuation characters ("!,.+-=")) are joined together with a single
   space and then formatted as a text block with each line starting at a common left position, and a right-margin
   allowing for full tokens.
- Special formatting for pragmas (as defined below) cause subsections to be reformatted according to the rules
   below.

Pragmas are identified by one of the following tokens as the first token of the line (after removing leading
 asterisks and whitespace): @param, @return, @field, @see.  The pragma-string extends from the pragma token until:
 the next pragma token or a blank line (after stripping asterisks and whitespace) or end-of-comment.

The following docstring pragma formats are supported:
- @param <param-name> <description>
- @return <description>
- @field <field-name> <description>
- @see <description>

Description strings can span multiple lines and any whitespace, including newlines, are stripped out
and reformatted appropriately for the desired output format.  Description strings are block formatted.

The <contents> section is scanned for pragma which cause sub-sections within <contents> to be formatted
as follows:
- @param -- "Parameter: <param-name> <description>"
- @return -- "Returns: <description>"
- @field -- "Field: <field-name> <description>"
- @see -- "See: <description>"

EXAMPLE:

ECL Source code:
--------------

/**
  * My module provides a module to perform important calculations.
  *                    My comments are not very well formatted
  *               but the documentation formatter
  * should take care of that.
  *
  * @param first_number                       The first number
  *  can do many things depending
  *                     on the context.
  
  * Good thing the formatter will clean this up
  *             @return The answer you are
  *   looking for.
  */
  
  
  EXPORT MyModule(REAL8 first_number):=MoDuLe
    ...
  /**
    * A very useful function
    * @param a_number the first parameter
    * @param a_string the second parameter
    * @return the definitive answer.
    
    */
    EXPORT MyFunction(REAL8 a_number STRING8 a_string) := funcTION
      ...
    END ;
    ...
  END;
-------------

The documentation output might be:

-------------

MODULE: MyModule(REAL8 first_number)

My module provides a module to perform important calculations.  My comments are not very well
formatted but the documentation formatter should take care of that
  
Parameter: first_number The first number can do many things depending on the context.  Good 
                        thing the formatter will clean this up
                        
Returns:                The answer you are looking for.

  FUNCTION: MyFunction(REAL8 a_number, STRING8 a_string)
  
  A very useful function
  
  Parameter: a_number the first parameter
  
  Parameter: a_string the second parameter
  
  Returns:   the definitive answer.

--------------
 
It is prefered that ECLDoc be designed in two stages.  The first would produce an intermediate 
form (XML) that captures the structure of the documentation.  The second stage, which could be data-driven
(e.g. style-sheets), would format the XML into either Text or HTML, and could be extended in the future to
handle other formats (e.g. windows help).

HTML formats could include features such as table-of-contents and links to various sections for the
convenience of the user.

