import { WebPartContext } from "@microsoft/sp-webpart-base";
import { IPickerTerms } from "@pnp/spfx-controls-react/lib/TaxonomyPicker";

export default interface ITaxonomyWrapper {
  allowMultipleSelections: boolean;
  termsetNameOrID: string;
  label: string;
  values: IPickerTerms;
  context: WebPartContext;
  loading: boolean;
  onValueChanged: (pickerTerms: any) => void;
}
