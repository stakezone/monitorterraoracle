# monitorterraoracle
Terra Oracle add-on for nodemonitorgaiad.

### Concept

oraclemonitor.sh produces logs that look like:

```sh
2020-04-14 23:49:44+00:00 status=synced blockheight=1602395 nmissedvotes=12737 pctmissedvotes=.95 amtukrw=779719662
2020-04-14 23:50:14+00:00 status=synced blockheight=1602400 nmissedvotes=12738 pctmissedvotes=1.00 amtukrw=779716162
2020-04-14 23:50:44+00:00 status=synced blockheight=1602405 nmissedvotes=12738 pctmissedvotes=1.00 amtukrw=779712662
```

The log line entries are:

* **status** can be {scriptstarted | error | catchingup | synced} 'error' can have various causes, typically the gaiad process is down
* **blockheight** blockheight from lcd call 
* **nmissedvotes** total number of missed votes
* **pctmissedvotes** percentage of last n missed votes from blockheight as configured in oraclemonitor.sh
* **amtukrw** amount of ukrw on feeder address

### Note

The related template is intended to be deployed alongside nodemonitorgaiad. Triggers are only for pctmissedvotes and amtukrw, and as well for no data received on 'status'.
