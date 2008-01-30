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
          
      
    - Judas: offers logging and notification methods.
      The notification functions are the following:
      
        * send_mail(mail_recipient_address, object, body, job_id) that sends 
          emails to the OAR admin
          
        * notify_user(base, method, host, user, job_id, job_name, tag, comments)
          that parses the notify method. This method can be a user script or a 
          mail to send. If the "method" field begins with 
          "mail:", notify_user will send an email to the user. If the 
          beginning is "exec:", it will execute the script as the "user".
          
      The main logging functions are the following:
      
        * redirect_everything() this function redirects STDOUT and STDERR into 
          the log file
          
        * oar_debug(message)
        
        * oar_warn(message)
        
        * oar_error(message)
        
      The three last functions are used to set the log level of the message.
      
      
    - Runner: 
    
        * for each job in "toError" state, answer to the oarsub client: 
          "BAD JOB". This will exit the client with an error code.
      
        * for each job in "toAckReservation" state, try to acknowledge the 
          oarsub client reservation. If runner cannot contact the client, it will 
          frag the job.
      
        * for each job to launch, launch job's bipbip.
      
    
    - NodeChangeState: this module's job is to change nodes states.
    
    
