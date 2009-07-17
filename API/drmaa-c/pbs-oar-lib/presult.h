

// POSSIBLE TYPES FOR A "presult" VARIABLE
enum{
   UNKNOWN,
   INTEGER,
   FLOAT,
   STRING,
   COMPLEX	// If it is an object or an array
};

 
// Structure of presult
struct element_
{
    char* key;
    int type;			// TYPE of the variable  (UNKNOWN when created)
    union {
       int i;
       float f;
       char* s;
    } immValue; 		// If it is not a complex value)
    struct element_ *compValue; // If it is a JSON object or a JSON array : for the moment it is also a presult 
    struct element_ *next;	// next presult element
};

// In order to avoid the "struct element_"
typedef struct element_ presult;


// The list of functions
presult* addElement();
void showResult();
void showResult_();
int isEmpty();
presult deleteElement();
presult findElement();
presult findElementNumber();
void removeResult();
void getDrmaaState();
