#*******************************************************************************
# @progdoc        emxExtractSchema.tcl v10.9
#
# @Brief:         Generates schema spinner files.
#
# @Description:   Generates schema spinner files.
#
# @Parameters:    Schema Primitive Type, Schema Name, Template, Date Range Filter, Spinner-Stamped Filter
#
# @Returns:       Nothing   
#
# @Usage:         Run in MQL:
#		  exec prog emxExtractSchema.tcl "Type 1, Type N" "Name";
#
#    Valid Examples:
#    a) Full schema						       exec prog emxExtractSchema.tcl * *
#    b) type - name			             exec prog emxExtractSchema.tcl type Part*
#    c) w/trigger params for b)      exec prog emxExtractSchema.tcl type Part* trigger
#    d) All templates  	             exec prog emxExtractSchema.tcl * template
#    e) Spinner-controlled schema	   exec prog emxExtractSchema.tcl * * "" spinner
#    f) Date Range                   exec prog emxExtractSchema.tcl * * "" "05/10/2009" "09/09/2009"
#
# @progdoc        Copyright (c) 2009, Dassault Systems, LLC
#*******************************************************************************
# @Modifications:
#
# See SchemaAgent_ReadMe.htm
#
#*******************************************************************************
tcl;

eval {
   set sHost [info host]

   if { $sHost == "sn732plp" } {
      source "c:/Program Files/TclPro1.3/win32-ix86/bin/prodebug.tcl"
      set cmd "debugger_eval"
      set xxx [debugger_init]
   } else {
      set cmd "eval"
   }
}
$cmd {

   set sSchemaType [mql get env 1]
   set sSchemaName [mql get env 2]
   set sParam3 [mql get env 3]

   set bTemplate FALSE
   set bSpinner FALSE
   set bTrigger FALSE
   set bAllSchema FALSE

   if {$sSchemaName == "template"} {
      set bTemplate TRUE
      set bSpinner FALSE
      set bTrigger FALSE
      set sGTEDate ""
      set sLTEDate ""
   } else {
      if {[string trim [string tolower $sParam3]] == "trigger"} {
         set bTrigger TRUE
      }
      set sGTEDate [mql get env 4]; # date range min value formatted mm/dd/yyyy
      if {[string trim [string tolower $sGTEDate]] == "spinner"} {
         set bSpinner TRUE
         set sGTEDate ""
         set sLTEDate ""
      } else {
         set sLTEDate [mql get env 5]; # date range max value formatted mm/dd/yyyy
      }
   }
   
   if {$sSchemaType == "" && $sSchemaName == ""} {
      puts "\nInvoke program in this manner: \
            \n  exec prog emxExtractSchema.tcl \"SchemaType 1,...,SchemaType N\" \"SchemaName\" \"param3\" \"param4\" \"param5\" \
            \n\n   Note: wildcards are allowed for SchemaName - use * (asterisk) for all schema. \
            \n    Valid Examples: \
            \n       exec prog emxExtractSchema.tcl * * (dump all schema)\
            \n       exec prog emxExtractSchema.tcl type Part* (all types beginning with Part) \
            \n    For templates, specify 'template' instead of name: \
            \n       exec prog emxExtractSchema.tcl * template \
            \n    To include trigger parameter bus objects, specify 'trigger' as param3: \
            \n       exec prog emxExtractSchema.tcl type Part* trigger \
            \n    To filter by Spinner-controlled, specify 'spinner' as param4: \
            \n       exec prog emxExtractSchema.tcl * * \"\" spinner \
            \n    To filter by from and to modified dates, specify dd,mm,yyyy in correct order as param4 and param5: \
            \n       exec prog emxExtractSchema.tcl * *  \"\" \"05/10/2009\" \"09/09/2009\""
      exit 1
      return
   }
   
   set sOS [string tolower $tcl_platform(os)];
   set sSuffix [clock format [clock seconds] -format "%Y%m%d"]
   if { [string tolower [string range $sOS 0 5]] == "window" } {
      set sSpinnerPath "c:/temp/SpinnerAgent$sSuffix";
   } else {
      set sSpinnerPath "/tmp/SpinnerAgent$sSuffix";
   }

   set sDumpSchemaDirSchema [ file join $sSpinnerPath Business ]
   file mkdir $sDumpSchemaDirSchema
   set sDumpSchemaDirFiles [ file join $sSpinnerPath "Business/SourceFiles" ]
   file mkdir $sDumpSchemaDirFiles
   set sDumpSchemaDirAccess [ file join $sSpinnerPath "Business/Policy" ]
   file mkdir $sDumpSchemaDirAccess
   set sDumpSchemaDirRuleAccess [ file join $sSpinnerPath "Business/Rule" ]
   file mkdir $sDumpSchemaDirRuleAccess
   set sDumpSchemaDirPageFiles [file join $sSpinnerPath "Business/PageFiles" ]
   file mkdir $sDumpSchemaDirPageFiles
   set sDumpSchemaDirSystem [ file join $sSpinnerPath System ]
   file mkdir $sDumpSchemaDirSystem
   set sDumpSchemaDirSystemMap [ file join $sSpinnerPath "System/Map" ]
   file mkdir $sDumpSchemaDirSystemMap
   set sDumpSchemaDirObjects [ file join $sSpinnerPath Objects ]
   file mkdir $sDumpSchemaDirObjects
   mql set env SPINNERPATH $sSpinnerPath
    
   set lsSchema [list \
      program \
      role \
      group \
      person \
      association \
      attribute \
      type \
      relationship \
      policy \
      command \
      inquiry \
      menu \
      table \
      webform \
      channel \
      portal \
      rule \
      interface \
      expression \
      page \
      dimension \
      site \
      location \
      store \
      server \
      vault \
      index \
	  format \
   ]

# Short Name Array and Generate List Array
   foreach sSchema $lsSchema {
      set sShortSchema [string range $sSchema 0 3]
      set aSchema($sSchema) $sShortSchema
      set bSchema($sSchema) FALSE
   }

   set sMxVersion [mql version]
   if {[string first "V6" $sMxVersion] >= 0} {
      set rAppend ""
	  if {[string range $sMxVersion 7 7] == "x"} {set rAppend ".1"}
      set sMxVersion [string range $sMxVersion 3 6]
	  if {$rAppend != ""} {append sMxVersion $rAppend}
   } else {
      set sMxVersion [join [lrange [split $sMxVersion .] 0 1] .]
   }
   mql set env MXVERSION $sMxVersion

   if {$sSchemaType == "*"} {
      foreach sSchema $lsSchema {
         set bSchema($sSchema) TRUE
      }
      if {$sSchemaName == "*"} {
         set bTrigger TRUE
         set bAllSchema TRUE
      }
   } else {
      set lsType [split $sSchemaType ,]
      foreach sType $lsType {
         set sType [string tolower [string trim $sType]]
         set bFlag FALSE
         foreach sSchema $lsSchema {
            if {[string range $sType 0 3] == $aSchema($sSchema)} {
               set bSchema($sSchema) TRUE
               set bFlag TRUE
               break
            } 
         }
         if {!$bFlag} {
            puts "ERROR: Schema type '$sType' is invalid.  Valid schema types are:\n [join $lsSchema ', ']"
            exit 1
            return
         }   
      }
   }
   
   # Set up arrays for symbolic name mapping
   
   set lsPropertyName [list ]
   set lsPropertyTo [list ]
   if {[mql list program "eServiceSchemaVariableMapping.tcl"] != ""} {
      set lsPropertyName [split [mql print program eServiceSchemaVariableMapping.tcl select property.name dump |] |]
      set lsPropertyTo [split [mql print program eServiceSchemaVariableMapping.tcl select property.to dump |] |]
   }
   mql set env PROPERTYNAME $lsPropertyName
   mql set env PROPERTYTO $lsPropertyTo

   if {$bSchema(program)} {
      mql exec prog emxExtractProgram.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      if {!$bAllSchema && !$bTemplate} {
         mql exec prog emxExtractProperty.tcl "program" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
      }
   }
   if {$bSchema(role)} {
      mql exec prog emxExtractRole.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      if {!$bAllSchema && !$bTemplate} {
         mql exec prog emxExtractProperty.tcl "role" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
      }
   }
   if {$bSchema(group)} {
      mql exec prog emxExtractGroup.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      if {!$bAllSchema && !$bTemplate} {
         mql exec prog emxExtractProperty.tcl "group" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
      }
   }
   if {$bSchema(person)} {
      mql exec prog emxExtractPerson.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      mql exec prog emxExtractPersonAccess.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      if {!$bAllSchema && !$bTemplate} {
         mql exec prog emxExtractProperty.tcl "person" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
      }
   }
   if {$bSchema(association)} {
      mql exec prog emxExtractAssociation.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      if {!$bAllSchema && !$bTemplate} {
         mql exec prog emxExtractProperty.tcl "association" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
      }
   }
   if {$bSchema(attribute)} {
      mql exec prog emxExtractAttribute.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      if {!$bAllSchema && !$bTemplate} {
         mql exec prog emxExtractTrigger.tcl "attribute" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
         if {$bTrigger} {
            set lsETPP [mql get env ETPPLIST]
            if {$lsETPP != ""} {
               set slsETPP [join $lsETPP ,]
               mql exec prog emxExtractObjectsRels.tcl "$slsETPP" "" "external" "" "" "" "att_$sSchemaName"
               mql unset env ETPPLIST
            }
         }
         mql exec prog emxExtractProperty.tcl "attribute" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
      }
   }
   if {$bSchema(type)} {
      mql exec prog emxExtractType.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      if {!$bAllSchema && !$bTemplate} {
         mql exec prog emxExtractTrigger.tcl "type" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
         if {$bTrigger} {
            set lsETPP [mql get env ETPPLIST]
            if {$lsETPP != ""} {
               set slsETPP [join $lsETPP ,]
               mql exec prog emxExtractObjectsRels.tcl "$slsETPP" "" "external" "" "" "" "type_$sSchemaName"
               mql unset env ETPPLIST
            }
         }
         mql exec prog emxExtractProperty.tcl "type" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
      }
   }
   if {$bSchema(relationship)} {
      mql exec prog emxExtractRelationship.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      if {!$bAllSchema && !$bTemplate} {
         mql exec prog emxExtractTrigger.tcl "relationship" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
         if {$bTrigger} {
            set lsETPP [mql get env ETPPLIST]
            if {$lsETPP != ""} {
               set slsETPP [join $lsETPP ,]
               mql exec prog emxExtractObjectsRels.tcl "$slsETPP" "" "external" "" "" "" "rel_$sSchemaName"
               mql unset env ETPPLIST
            }
         }
         mql exec prog emxExtractProperty.tcl "relationship" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
      }
   }
   if {$bSchema(format)} {
      mql exec prog emxExtractFormat.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      if {!$bAllSchema && !$bTemplate} {
         mql exec prog emxExtractProperty.tcl "format" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
      }
   }
   if {$bSchema(policy)} {
      mql exec prog emxExtractPolicy.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      mql exec prog emxExtractPolicyStateAccess.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      if {!$bAllSchema && !$bTemplate} {
         mql exec prog emxExtractTrigger.tcl "policy" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
         if {$bTrigger} {
            set lsETPP [mql get env ETPPLIST]
            if {$lsETPP != ""} {
               set slsETPP [join $lsETPP ,]
               mql exec prog emxExtractObjectsRels.tcl "$slsETPP" "" "external" "" "" "" "pol_$sSchemaName"
               mql unset env ETPPLIST
            }
         }
         mql exec prog emxExtractProperty.tcl "policy" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
      }
   }
   if {$bSchema(command) && $sMxVersion >= 9.5} {
      mql exec prog emxExtractCommand.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      if {!$bAllSchema && !$bTemplate} {
         mql exec prog emxExtractProperty.tcl "command" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
      }
   }
   if {$bSchema(inquiry) && $sMxVersion >= 9.5} {
      mql exec prog emxExtractInquiry.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      if {!$bAllSchema && !$bTemplate} {
         mql exec prog emxExtractProperty.tcl "inquiry" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
      }
   }
   if {$bSchema(menu) && $sMxVersion >= 9.5} {
      mql exec prog emxExtractMenu.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      if {!$bAllSchema && !$bTemplate} {
         mql exec prog emxExtractProperty.tcl "menu" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
      }
   }
   if {$bSchema(table) && $sMxVersion >= 9.5} {
      if {$sSchemaName != "*"} {
         set sSchemaName "*"
         puts "NOTICE - No filter option for tables - * is used"
      }
      mql exec prog emxExtractTable.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      if {!$bAllSchema && !$bTemplate} {
         mql exec prog emxExtractProperty.tcl "table" "*" "$bSpinner" "$sLTEDate" "$sGTEDate"
      }
   }
   if {$bSchema(webform) && $sMxVersion >= 9.6} {
      mql exec prog emxExtractWebForm.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      if {!$bAllSchema && !$bTemplate} {
         mql exec prog emxExtractProperty.tcl "form" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
      }
   }
   if {$bSchema(channel) && $sMxVersion >= 10.5} {
      mql exec prog emxExtractChannel.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      if {!$bAllSchema && !$bTemplate} {
         mql exec prog emxExtractProperty.tcl "channel" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
      }
   }
   if {$bSchema(portal) && $sMxVersion >= 10.5} {
      mql exec prog emxExtractPortal.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      if {!$bAllSchema && !$bTemplate} {
         mql exec prog emxExtractProperty.tcl "portal" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
      }
   }
   if {$bSchema(rule)} {
      mql exec prog emxExtractRule.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      mql exec prog emxExtractRuleAccess.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      if {!$bAllSchema && !$bTemplate} {
         mql exec prog emxExtractProperty.tcl "rule" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
      }
   }
   if {$bSchema(interface) && $sMxVersion >= 10.6} {
      mql exec prog emxExtractInterface.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      if {!$bAllSchema && !$bTemplate} {
         mql exec prog emxExtractProperty.tcl "interface" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
      }
   }
   if {$bSchema(expression) && $sMxVersion >= 10.6} {
      mql exec prog emxExtractExpression.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      if {!$bAllSchema && !$bTemplate} {
         mql exec prog emxExtractProperty.tcl "expression" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
      }
   }
   if {$bSchema(page)} {
      mql exec prog emxExtractPage.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      if {!$bAllSchema && !$bTemplate} {
         mql exec prog emxExtractProperty.tcl "page" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
      }
   }
   if {$bSchema(dimension) && $sMxVersion >= 10.7} {
      mql exec prog emxExtractDimension.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      if {!$bAllSchema && !$bTemplate} {
         mql exec prog emxExtractProperty.tcl "dimension" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
      }
   }
   if {$bSchema(site)} {
      if {$sSchemaName != "*"} {
         set sSchemaName "*"
         puts "NOTICE - No filter option for sites - * is used"
      }
      mql exec prog emxExtractSite.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      if {!$bAllSchema && !$bTemplate} {
         mql exec prog emxExtractProperty.tcl "site" "*" "$bSpinner" "$sLTEDate" "$sGTEDate"
      }
   }
   if {$bSchema(location)} {
      mql exec prog emxExtractLocation.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      if {!$bAllSchema && !$bTemplate} {
         mql exec prog emxExtractProperty.tcl "location" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
      }
   }
   if {$bSchema(store)} {
      mql exec prog emxExtractStore.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      if {!$bAllSchema && !$bTemplate} {
         mql exec prog emxExtractProperty.tcl "store" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
      }
   }
   if {$bSchema(server)} {
      mql exec prog emxExtractServer.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      if {!$bAllSchema && !$bTemplate} {
         mql exec prog emxExtractProperty.tcl "server" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
      }
   }
   if {$bSchema(vault)} {
      mql exec prog emxExtractVault.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      if {!$bAllSchema && !$bTemplate} {
         mql exec prog emxExtractProperty.tcl "vault" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
      }
   }
   if {$bSchema(index)} {
      mql exec prog emxExtractIndex.tcl "$sSchemaName" "$bTemplate" "$bSpinner" "$sLTEDate" "$sGTEDate"
      if {!$bAllSchema && !$bTemplate} {
         mql exec prog emxExtractProperty.tcl "index" "$sSchemaName" "$bSpinner" "$sLTEDate" "$sGTEDate"
      }
   }
   if {$bAllSchema} {
      mql exec prog emxExtractPropertyAll.tcl $lsSchema "*" "$bSpinner" "$sLTEDate" "$sGTEDate"
      mql exec prog emxExtractTriggerAll.tcl "[list attribute type relationship policy]" "*" "$bSpinner" "$sLTEDate" "$sGTEDate"
      mql exec prog emxExtractObjectsRels.tcl "eService*" "eService*"
   }
}