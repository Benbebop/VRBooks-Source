# pdflib

object oriented parseing of pdf files

# syntax

**pdf**

*pdf.Open( pdffile )

open and initialize a pdf file

*pdf.Download( url )

download a pdf to files

*pdf.ScanPDF()

scans for pdfs in the data/pdf/ diretory

*pdf.GetMetadata()

gets the metadata file withing data/pdf/

**root_class**

base for the entire pdf file, contains all objects and data

*root_class:_Parse( f )

internal function, used to parse a file containing a pdf object

*root_class:LoadObject( objectIndex )

loads object into memory, *does not return it*

*root_class:_FindPage( pageIndex )

internal function, finds the page object associated with the pageIndex

*root_class:LoadPage( pageIndex )

loads all objects within a page into memory, *does not return them*

*root_class:GetObject( index )

returns an object, automatically loads objects that are not yet loaded

*root_class:UncacheObject( index )

unloads an object from memory

*root_class:GetPage( pageIndex )

get objects contained within a page

*root_class:_constructArray( f )

internal function, used to parse a file containing a pdf array

*root_class:_constructStream( f, dict )

internal function, used to parse a file containing a pdf stream

*root_class:init()

initializes everything inside of a root_class, must be called before doing anything else

**page_class**

similar to root_class but only for a single page

**name_class**

object representing a name in a pdf file, a name object is atomic, meaning objects with the same name are the same instance

*name_class:GetName()

returns string name of a name

*name_class:GetAtomicID()

returns the internal id of the name

**dict_class**

object representing a dictonary in a pdf file, works similarly to a lua table but with extra functions and direct object support

*dict_class:_Table()

turns the dictonary into a lua table, *waring, pdf_ref objects must be called manually*

*dict_class._GetRaw( index )

gets a value without calling direct objects

*dict_class:Iter()

returns an itterator for the dictonary

**array_class**

all methods that apply for dict_class also apply here, only difference being it uses numerical indecies

**stream_class**

object representing a pdf data stream

**ref_class**

a direct object, when called returns the object
