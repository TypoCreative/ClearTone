# Is it possible to change supported FRAME_SIZE? · Issue #93 · xiph/rnnoise · GitHub

> Source: https://github.com/xiph/rnnoise/issues/93
> Cached: 2026-07-21T14:30:46.610Z

---

Uh oh!

              There was an error while loading. [Please reload this page]().

  
  

    

  

  

      

        
            
  
      
    

    
    
      
        xiph
    
    /
    
      [rnnoise](/xiph/rnnoise)
    

    Public
  

        

        
            

    
      

  
                
    
Notifications
    You must be signed in to change notification settings

  

  
              
    
Fork
    1.1k

  

  
        
            
    

          Star
          5.7k

  

        
      

        

          

  

      
  
    
              
    

        Code
          

    

      
  
    
              
    

        Issues
          182

    

      
  
    
              
    

        Pull requests
          22

    

      
  
    
              
    

        Actions
          

    

      
  
    
              
    

        Projects
          

    

      
  
    
              
    

        Security and quality
          0

    

      
  
    
              
    

        Insights
          

    

          
  
      
    

Additional navigation options

  
    
                
  
    

        
    
    
    
        
          
    

        
      
        
          Code
      

  

        
    
    
    
        
          
    

        
      
        
          Issues
      

  

        
    
    
    
        
          
    

        
      
        
          Pull requests
      

  

        
    
    
    
        
          
    

        
      
        
          Actions
      

  

        
    
    
    
        
          
    

        
      
        
          Projects
      

  

        
    
    
    
        
          
    

        
      
        
          Security and quality
      

  

        
    
    
    
        
          
    

        
      
        
          Insights
      

  

    

      
  

  
  

    
    

    
      
    

  

  
  
  # Is it possible to change supported FRAME_SIZE? #93

New issueCopy linkNew issueCopy linkOpenOpen[Is it possible to change supported FRAME_SIZE?](#top)#93Copy link## Description

[](https://github.com/Ornolfr)[Ornolfr](https://github.com/Ornolfr)opened [on Sep 27, 2019](https://github.com/xiph/rnnoise/issues/93#issue-499356130)Issue body actionsThank you for this spectacular library! It is a very powerful tool that can be used in real time for real world applications.

However, in Android, the frame size may vary per device and API being used (Java SDK, OpenSL ES, AAudio) basis - from less than 150 up to thousands of values in buffer. The library supports only 480 as the frame size and crashes/produces audio glitches when I send the audio buffer to processing.

Is it possible to make the frame size variable?

Reactions are currently unavailable## Metadata

## Metadata

### Assignees

No one assigned

### Labels

No labelsNo labels### Type

No type### Fields

No fields configured for issues without a type.### Projects

No projects### Milestone

No milestone

### Relationships

None yet### Development

No branches or pull requests## Issue actions

- Open in GitHub Copilot app