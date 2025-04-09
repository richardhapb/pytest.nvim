; inherits: python
; extends
;
(assert_statement) @assert

(function_definition
  name: (identifier) @function_name
  body: (block) @function_body
) @function

(class_definition
  name: (identifier) @class_name
  body: (block   
          (function_definition) @class_method
        ) @class_body
) @class

(class_definition
  body: (block
   (decorated_definition
       definition: (function_definition) @class_method
   )
        )
)
