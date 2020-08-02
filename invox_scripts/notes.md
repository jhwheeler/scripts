# Data Flow

- *Input*: process timesheet from stdin
- *Timesheet*: format timesheet into a map with start date, end date, hours worked
- *Config*: parse config file
- *Report*: combine info from config and formatted timesheet into one map,
- *Invoice*: replace placeholders in invoice template with attributes from previous map
