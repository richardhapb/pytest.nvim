; inherits: xml
; extends
;
(EmptyElemTag) @passed
(EmptyElemTag (Name) @passed_name (Attribute) @passed_att)
(EmptyElemTag 
  (Attribute 
    (Name) @passed_att_name
    (AttValue) @passed_att_value
  )
) 

(STag) @tag
(STag (Name)@tag_name (Attribute) @tag_att) 

(STag 
  (Attribute 
    (Name) @att_name
    (AttValue) @att_value
  )
)

(element) @element

(element 
  (content 
    (element 
      (content 
        (element 
          (content 
            (element 
              (STag 
                (Name) @not_passed_name 
                (Attribute 
                  (Name) @not_passed_att_name
                  (AttValue) @not_passed_att_value
                ) @not_passed_att
              )
                (content) @not_passed_content 
            )
          )
        )
      )
    )
  )
)

(element 
  (content 
    (element 
      (content 
        (element 
          (content 
            (element 
              (STag)  @not_passed
            )
          )
        )
      )
    )
  )
)

