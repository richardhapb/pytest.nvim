; inherits: xml
; extends
;
(EmptyElemTag) @case
(EmptyElemTag (Name) @case_name (Attribute) @case_att)
(EmptyElemTag 
  (Attribute 
    (Name) @case_att_name
    (AttValue) @case_att_value
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
              (STag) @err
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
              (STag 
                (Attribute 
                  (Name) @err_att_name
                  (AttValue) @err_att_value
                )
              ) 
                (content) @err_content 
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
              (STag 
                (Name) @err_name 
                (Attribute) @err_att
              ) 
                (content) @err_content 
            )
          ) 
        ) 
      )
    )
  )
)

