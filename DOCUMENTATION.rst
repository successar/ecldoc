================
ECLDOC
================

Purpose
=======
Ecldoc is a tool for generating API Documentation for ECL Project based on their docstrings. The executable ``ecldoc`` is the main program that parses the sources and generate Documentation.

Usage
=====
An ECL Project (according to ECLDOC) consists of a complete source tree (that is recursively scanned) within a given input directory (hereby known as INPUT ROOT) . By default, ecldoc generated documentation for all files within INPUT ROOT, but user can override that to specify Unix style GLOB pattern for files to include and for files to exclude within ECL Project. GLOB patterns are specified relative to INPUT ROOT (See Examples).

User also needs to specify OUTPUT ROOT that is the directlry where documentation will be stored for all formats (ECLDOC will create OUTPUT ROOT if not present already; otherise it will be overwritten).

ECLDOC currently supports documentation in 3 formats – HTML, Text, PDF (via LATEX). Outputs for each format are present as follows :
<OUTPUT ROOT>/<format>/<source tree> where source tree is ecl source tree within INPUT ROOT (and satisfying include and exclude criteria)

User can specify these options on either the command line or in the configuration file.

Major Steps
===========
Documentation is generated in 3 major steps
 Call ECLCC -M for each ecl file to generate XML Output (Called xmlOriginal)
#. Parse xmlOriginal for all file to generate Processed XML (Called XML)
#. Convert XML into required Output Formats

Parsing xmlOriginal to XML
==========================
The XML Documentation generator ``GenXML`` takes in 4 variables :

#. Input Root
#. Output Root
#. Ecl files - list of ecl files to be parsed
#. Options - Other ecldoc options

``GenXML`` recreates path tree from ecl files.
E.g.
ECL Files : [A1.ecl, A2.ecl, B/B1.ecl, C/C1.ecl, B/D/D1.ecl]

Ecl File Tree :

..code:: json
{ root :
  { A1.ecl : 'A1.ecl' ,
    A2.ecl : 'A2.ecl' ,
    C :
      { C1.ecl : 'C/C1.ecl' } ,
	B :
      { B1.ecl : 'B/B1.ecl',
        D :
       	  { D1.ecl : 'B/D/D1.ecl' }
	  },
  }
}
```

For each file in ecl file tree, ``GenXML`` creates a ``ParseXML`` object to parse that file.
Major Steps during conversion from xmlOriginal to XML in ``ParseXML`` are

#. Keep only Source Tag corresponding to given file
#. Convert all other SOurce Tags into Depend Tags, keeping only name and sourcepath
#. Process All Definitions in Source

   #. Check if definitions should be kept (internal, no docstring, etc) or removed
   #. Generate Signature by reading ecl source file
   #. Break docstring into individual tags
   #. Link References (Imports, Parents, External Attributes)

#. Remove Source from ecl file tree if no Definitions present


Parsing XML to Formats
======================
Each format is specified in terms of a generator class of form - Gen<FORMAT>.
Each generator class object takes in 4 variables during init :

- Input Root Path
- Output Root Path
- ECL File Tree (Source Tree) returned by XML generator after processing
- Options - Other ecldoc options

Each generator should have a ``run()`` method that is called by ecldoc to generate its documentation. These are the only requirements for the generator class.

Common Structure of Generator is as follows :
For each file in ecl file tree, ``Gen<FORMAT>`` creates a ``Parse<FORMAT>`` object to parse corresponding xml file.
There are no restrictions on how ``Parse<FORMAT>`` object works, but common steps are :

#. Convert all links to correspond to given format
#. Convert all Documentations into given Format (using Taglet API if needed)

Taglet API
==========
Each Tag type in Documentation can have a corresponding Taglet class which extracts necessary information from its XML Representation into Python object. This information can be used to easily render that tag in any format. Other processing can also occur in taglets-
e.g. Parameter docstrings are linked with parameter types, etc.
Each taglets class takes in 3 variables :

- Name of that tag in docstring
- All tag strings in given docstring for that tag
- Corresponding Definition Element for that docstring
