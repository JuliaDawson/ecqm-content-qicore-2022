/*
@update: BTR 2020-03-31 ->
Incremented version to 5.0.000
Updated FHIR version to 4.0.1
Changed timezone keyword to timezoneoffset for use with CQL 1.4
Removed Normalize Onset in favor of more general Normalize Interval
Updated CodeSystems for ConditionVerificationStatusCodes and RoleCodes

@update: BTR 2021-05-13 ->
Added ActiveCondition Codes and Inactive Condition Codes value sets
Added function documentation throughout
Fixed EDVisit not using Last
Updated prevalence period to use an inclusive boundary if the condition is active
Added HasStart, HasEnd, Earliest, and Latest functions
Removed ToDate and Age calculation functions

@update: BTR 2021-06-25 ->
Added GetBaseExtension overloads for Element

@update: BTR 2022-05-24 ->
Update for 2022 AU content
Refactor to use CQF.FHIRCommon

@update: BTR 2022-06-14 ->
Update to use QICore
Rename from MATGlobalCommonFunctionsFHIR4 to MATGlobalCommonFunctionsQICore4
Added fluent functions
Removed Normalize Interval
*/
library MATGlobalCommonFunctionsQICore4 version '7.0.000'

using QICore version '4.1.1'

include FHIRHelpers version '4.0.012' called FHIRHelpers
include FHIRCommon version '4.0.012' called FHIRCommon

valueset "Emergency Department Visit": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.117.1.7.1.292'
valueset "Encounter Inpatient": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.666.5.307'
valueset "Intensive Care Unit": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1029.206'
valueset "Observation Services": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1111.143'
valueset "Outpatient Surgery Service": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1110.38'
valueset "Present on Admission or Clinically Undetermined": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1147.197'

parameter "Measurement Period" Interval<DateTime>
  default Interval[@2022-01-01T00:00:00.0, @2023-01-01T00:00:00.0)

context Patient

define "Inpatient Encounter":
  [Encounter: "Encounter Inpatient"] EncounterInpatient
		where EncounterInpatient.status = 'finished'
	    and "LengthInDays"(EncounterInpatient.period) <= 120
			and EncounterInpatient.period ends during day of "Measurement Period"

/*
@description: Returns an interval of date values extracted from the input interval of date-time values
@comment: This function returns an interval constructed using the `date from` extractor on the start
and end values of the input date-time interval. Note that using a precision specifier such as `day of`
as part of a timing phrase is preferred to communicate intent to perform day-level comparison, as well
as for general readability.
*/
define function "ToDateInterval"(period Interval<DateTime>):
  Interval[date from start of period, date from end of period]

/*
Calculates the difference in calendar days between the start and end of the given interval.
*/
define function "LengthInDays"(Value Interval<DateTime> ):
  difference in days between start of Value and end of Value

/*
Calculates the difference in calendar days between the start and end of the given interval.
*/
define fluent function lengthInDays(Value Interval<DateTime> ):
  difference in days between start of Value and end of Value

/*
Returns the most recent emergency department visit, if any, that occurs 1 hour or less prior to the given encounter.
*/
define function "ED Visit"(TheEncounter Encounter ):
  Last(
    [Encounter: "Emergency Department Visit"] EDVisit
      where EDVisit.status = 'finished'
        and EDVisit.period ends 1 hour or less on or before start of TheEncounter.period
      sort by end of period
    )

/*
Returns the most recent emergency department visit, if any, that occurs 1 hour or less prior to the given encounter.
*/
define fluent function edVisit(TheEncounter Encounter ):
  Last(
    [Encounter: "Emergency Department Visit"] EDVisit
      where EDVisit.status = 'finished'
        and EDVisit.period ends 1 hour or less on or before start of TheEncounter.period
      sort by end of period
    )

/*
Hospitalization returns the total interval for admission to discharge for the given encounter, or for the admission of any immediately prior emergency department visit to the discharge of the given encounter.
*/
define function "Hospitalization"(TheEncounter Encounter ):
  ( "ED Visit"(TheEncounter) ) X
    return
        if X is null then TheEncounter.period
        else Interval[start of X.period, end of TheEncounter.period)

/*
Hospitalization returns the total interval for admission to discharge for the given encounter, or for the admission of any immediately prior emergency department visit to the discharge of the given encounter.
*/
define fluent function hospitalization(TheEncounter Encounter ):
  ( "ED Visit"(TheEncounter) ) X
    return
        if X is null then TheEncounter.period
        else Interval[start of X.period, end of TheEncounter.period]

/*
Returns list of all locations within an encounter, including locations for immediately prior ED visit.
*/
define function "Hospitalization Locations"(TheEncounter Encounter ):
  ( "ED Visit"(TheEncounter) ) EDEncounter
    return
        if EDEncounter is null then TheEncounter.location
        else flatten { EDEncounter.location, TheEncounter.location }

/*
Returns list of all locations within an encounter, including locations for immediately prior ED visit.
*/
define fluent function hospitalizationLocations(TheEncounter Encounter ):
  ( "ED Visit"(TheEncounter) ) EDEncounter
    return
        if EDEncounter is null then TheEncounter.location
        else flatten { EDEncounter.location, TheEncounter.location }

/*
Returns the length of stay in days (i.e. the number of days between admission and discharge) for the given encounter, or from the admission of any immediately prior emergency department visit to the discharge of the encounter
*/
define function "Hospitalization Length of Stay"(TheEncounter Encounter ):
  LengthInDays("Hospitalization"(TheEncounter))

/*
Returns the length of stay in days (i.e. the number of days between admission and discharge) for the given encounter, or from the admission of any immediately prior emergency department visit to the discharge of the encounter
*/
define fluent function hospitalizationLengthOfStay(TheEncounter Encounter ):
  LengthInDays("Hospitalization"(TheEncounter))

/*
Returns admission time for an encounter or for immediately prior emergency department visit.
*/
define function "Hospital Admission Time"(TheEncounter Encounter ):
  start of "Hospitalization"(TheEncounter)

/*
Returns admission time for an encounter or for immediately prior emergency department visit.
*/
define fluent function hospitalAdmissionTime(TheEncounter Encounter ):
  start of "Hospitalization"(TheEncounter)

/*
Hospital Discharge Time returns the discharge time for an encounter
*/
define function "Hospital Discharge Time"(TheEncounter Encounter ):
  end of TheEncounter.period

/*
Hospital Discharge Time returns the discharge time for an encounter
*/
define fluent function hospitalDischargeTime(TheEncounter Encounter ):
  end of TheEncounter.period

/*
Returns earliest arrival time for an encounter including any prior ED visit.
*/
define function "Hospital Arrival Time"(TheEncounter Encounter ):
  start of First(
  	    ( "Hospitalization Locations"(TheEncounter) ) HospitalLocation
  			sort by start of period
  	).period

/*
Returns earliest arrival time for an encounter including any prior ED visit.
*/
define fluent function hospitalArrivalTime(TheEncounter Encounter ):
  start of First(
  	    ( "Hospitalization Locations"(TheEncounter) ) HospitalLocation
  			sort by start of period
  	).period

/*
Returns the latest departure time for encounter including any prior ED visit. 
*/
define function "Hospital Departure Time"(TheEncounter Encounter):
	end of Last(
	    ( "Hospitalization Locations"(TheEncounter) ) HospitalLocation
			sort by start of period
	).period

/*
Returns the latest departure time for encounter including any prior ED visit. 
*/
define fluent function hospitalDepartureTime(TheEncounter Encounter):
	end of Last(
	    ( "Hospitalization Locations"(TheEncounter) ) HospitalLocation
			sort by start of period
	).period

define function "Emergency Department Arrival Time"(TheEncounter Encounter):
	start of (
	    singleton from (
	        ( "Hospitalization Locations"(TheEncounter) ) HospitalLocation
				where GetLocation(HospitalLocation.location).type in "Emergency Department Visit"
		)
	).period

define fluent function emergencyDepartmentArrivalTime(TheEncounter Encounter):
	start of (
	    singleton from (
	        ( "Hospitalization Locations"(TheEncounter) ) HospitalLocation
				where GetLocation(HospitalLocation.location).type in "Emergency Department Visit"
		)
	).period

/*
Hospitalization with Observation and Outpatient Surgery Service returns the total interval from the start of any immediately prior emergency department visit, outpatient surgery visit or observation visit to the discharge of the given encounter.
*/
define function "HospitalizationWithObservationAndOutpatientSurgeryService"(TheEncounter "Encounter" ):
  TheEncounter Visit
	  let ObsVisit: Last([Encounter: "Observation Services"] LastObs
		  	where LastObs.status = 'finished'
          and LastObs.period ends 1 hour or less on or before start of Visit.period
			  sort by	end of period
    	),
    	VisitStart: Coalesce(start of ObsVisit.period, start of Visit.period),
    	EDVisit: Last([Encounter: "Emergency Department Visit"] LastED
			  where LastED.status = 'finished'
          and LastED.period ends 1 hour or less on or before VisitStart
			  sort by	end of period
    	),
    	VisitStartWithED: Coalesce(start of EDVisit.period, VisitStart),
    	OutpatientSurgeryVisit: Last([Encounter: "Outpatient Surgery Service"] LastSurgeryOP
			  where LastSurgeryOP.period ends 1 hour or less on or before VisitStartWithED
			  sort by	end of period
    	)
  	return Interval[Coalesce(start of OutpatientSurgeryVisit.period, VisitStartWithED), end of Visit.period]

/*
Hospitalization with Observation and Outpatient Surgery Service returns the total interval from the start of any immediately prior emergency department visit, outpatient surgery visit or observation visit to the discharge of the given encounter.
*/
define fluent function hospitalizationWithObservationAndOutpatientSurgeryService(TheEncounter "Encounter" ):
  TheEncounter Visit
	  let ObsVisit: Last([Encounter: "Observation Services"] LastObs
		  	where LastObs.status = 'finished'
          and LastObs.period ends 1 hour or less on or before start of Visit.period
			  sort by	end of period
    	),
    	VisitStart: Coalesce(start of ObsVisit.period, start of Visit.period),
    	EDVisit: Last([Encounter: "Emergency Department Visit"] LastED
			  where LastED.status = 'finished'
          and LastED.period ends 1 hour or less on or before VisitStart
			  sort by	end of period
    	),
    	VisitStartWithED: Coalesce(start of EDVisit.period, VisitStart),
    	OutpatientSurgeryVisit: Last([Encounter: "Outpatient Surgery Service"] LastSurgeryOP
			  where LastSurgeryOP.period ends 1 hour or less on or before VisitStartWithED
			  sort by	end of period
    	)
  	return Interval[Coalesce(start of OutpatientSurgeryVisit.period, VisitStartWithED), end of Visit.period]

/*
Hospitalization with Observation returns the total interval from the start of any immediately prior emergency department visit through the observation visit to the discharge of the given encounter
*/
define function "HospitalizationWithObservation"(TheEncounter Encounter ):
  TheEncounter Visit
  		let ObsVisit: Last([Encounter: "Observation Services"] LastObs
  				where LastObs.status = 'finished'
            and LastObs.period ends 1 hour or less on or before start of Visit.period
  				sort by end of period
  			),
  			VisitStart: Coalesce(start of ObsVisit.period, start of Visit.period),
  			EDVisit: Last([Encounter: "Emergency Department Visit"] LastED
  				where LastED.status = 'finished'
            and LastED.period ends 1 hour or less on or before VisitStart
  				sort by end of period
  			)
  		return Interval[Coalesce(start of EDVisit.period, VisitStart), end of Visit.period]

/*
Hospitalization with Observation returns the total interval from the start of any immediately prior emergency department visit through the observation visit to the discharge of the given encounter
*/
define fluent function hospitalizationWithObservation(TheEncounter Encounter ):
  TheEncounter Visit
  		let ObsVisit: Last([Encounter: "Observation Services"] LastObs
  				where LastObs.status = 'finished'
            and LastObs.period ends 1 hour or less on or before start of Visit.period
  				sort by end of period
  			),
  			VisitStart: Coalesce(start of ObsVisit.period, start of Visit.period),
  			EDVisit: Last([Encounter: "Emergency Department Visit"] LastED
  				where LastED.status = 'finished'
            and LastED.period ends 1 hour or less on or before VisitStart
  				sort by end of period
  			)
  		return Interval[Coalesce(start of EDVisit.period, VisitStart), end of Visit.period]

/*
Hospitalization with Observation Length of Stay returns the length in days from the start of any immediately prior emergency department visit through the observation visit to the discharge of the given encounter
*/
define function "HospitalizationWithObservationLengthofStay"(TheEncounter "Encounter" ):
  "LengthInDays"("HospitalizationWithObservation"(TheEncounter))

/*
Hospitalization with Observation Length of Stay returns the length in days from the start of any immediately prior emergency department visit through the observation visit to the discharge of the given encounter
*/
define fluent function hospitalizationWithObservationLengthofStay(TheEncounter "Encounter" ):
  "LengthInDays"("HospitalizationWithObservation"(TheEncounter))

/*
First Inpatient Intensive Care Unit returns the first intensive care unit for the given encounter, without considering any immediately prior emergency department visit.
*/
define function "FirstInpatientIntensiveCareUnit"(Encounter Encounter ):
  First((Encounter.location)HospitalLocation
  			where GetLocation(HospitalLocation.location).type in "Intensive Care Unit"
  				and HospitalLocation.period during Encounter.period
  			sort by start of period
  	)

/*
First Inpatient Intensive Care Unit returns the first intensive care unit for the given encounter, without considering any immediately prior emergency department visit.
*/
define fluent function firstInpatientIntensiveCareUnit(Encounter Encounter ):
  First((Encounter.location)HospitalLocation
  			where GetLocation(HospitalLocation.location).type in "Intensive Care Unit"
  				and HospitalLocation.period during Encounter.period
  			sort by start of period
  	)

/*
Returns the Condition resources referenced by the diagnosis element of the Encounter
*/
define function "EncounterDiagnosis"(Encounter Encounter ):
  Encounter.diagnosis D
    return singleton from ([Condition] C where C.id = D.condition.reference.getId())

/*
Returns the Condition resources referenced by the diagnosis element of the Encounter
*/
define fluent function encounterDiagnosis(Encounter Encounter ):
  Encounter.diagnosis D
    return singleton from ([Condition] C where C.id = D.condition.reference.getId())

/*
Returns the Condition resource for the given reference
*/
define function "GetCondition"(reference Reference):
  singleton from ([Condition] C where C.id = reference.reference.getId())

/*
Returns the Condition resource for the given reference
*/
define fluent function getCondition(reference Reference):
  singleton from ([Condition] C where C.id = reference.reference.getId())

/*
Returns the condition that is specified as the principal diagnosis for the encounter
*/
define function "PrincipalDiagnosis"(Encounter Encounter ):
  // TODO: Encounter.diagnosis is coming through as a singleton, issue with the model info generation
  (Encounter.diagnosis D where D.rank = 1) PD
  //(singleton from (Encounter.diagnosis D where D.rank = 1)) PD
  		return singleton from ([Condition] C where C.id = PD.condition.reference.getId())

/*
Returns the condition that is specified as the principal diagnosis for the encounter
*/
define fluent function principalDiagnosis(Encounter Encounter ):
  // TODO: Encounter.diagnosis is coming through as a singleton, issue with the model info generation
  (Encounter.diagnosis D where D.rank = 1) PD
  //(singleton from (Encounter.diagnosis D where D.rank = 1)) PD
  		return singleton from ([Condition] C where C.id = PD.condition.reference.getId())

/*
Returns the Location resource specified by the given reference
*/
define function "GetLocation"(reference Reference ):
  singleton from (
    [Location] L where L.id = reference.reference.getId()
  )

/*
Returns the Location resource specified by the given reference
*/
define fluent function getLocation(reference Reference ):
  singleton from (
    [Location] L where L.id = reference.reference.getId()
  )

/*
Returns the medication code for the given MedicationRequest
*/
define function "GetMedicationCode"(request MedicationRequest ):
  if request.medication is Concept then
  	  request.medication as Concept
  	else
  	  (singleton from ([Medication] M where M.id = (request.medication as Reference).reference.getId())).code

/*
Returns the medication code for the given MedicationRequest
*/
define fluent function getMedicationCode(request MedicationRequest ):
  if request.medication is Concept then
  	  request.medication as Concept
  	else
  	  (singleton from ([Medication] M where M.id = (request.medication as Reference).reference.getId())).code

