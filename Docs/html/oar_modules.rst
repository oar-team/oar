OAR modules
============

    - Almighty: almighty is the oar server. It's an automaton that listens to 
      client messages and orchestrates the execution of the different modules. 
      It's behaviour is represented in these schemes.
      
      * General schema:
      
      .. image:: schemas/almighty_automaton_general.png
      
      * Scheduler schema: 
      
      .. image:: schemas/almighty_automaton_scheduler_part.png
      
      * Finaud schema: 
      
      .. image:: schemas/almighty_automaton_finaud_part.png
      
      * Leon schema:
      
      .. image:: schemas/almighty_automaton_leon_part.png
      
      * Sarko schema:
          
      .. image:: schemas/almighty_automaton_villains_part.png

      * ChangeNode schema:
      
      .. image:: schemas/almighty_automaton_changenode_part.png
      
      
    - Sarko: sarko module's job is to keep watch over jobs. Here is it's 
      comportment:
      
        * for each job whose frag_state value is TIMER_ARMED, set it to FRAGGED 
          if it's terminated, in error or finishing and to EXTERMINATE otherwise
          
        * for each running job, recalculate it's walltime if it's suspended, add
          it to the table of jobs to frag if it's walltime is outdated and 
          checkpoint jobs that need it.
          
        * set to suspected expired resources and send to Almighty a "Chstate"
          message (special for Desktop Computing)
          
        * set to dead old suspected resources and send to Almighty a "Chstate"
          message
          
      
