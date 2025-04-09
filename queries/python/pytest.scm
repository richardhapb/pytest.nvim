; inherits: python
; extends
;
(assert_statement) @assert

(function_definition
  name: (identifier) @function_name
  body: (block) @function_body
) @function

(class_definition
  name: (identifier) @test_class_name
  body: (block   
          (function_definition) @test_class_method
        ) @test_class_body
) @test_class

(class_definition
  body: (block
   (decorated_definition
       definition: (function_definition) @test_class_method
   )
        )
)
