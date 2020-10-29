import { IPickerTerms } from "@pnp/spfx-controls-react/lib/TaxonomyPicker";

export interface IDocProcessorState {
  uploads: any[];
  projects: IPickerTerms;
  submittalAction: IPickerTerms;
  gaPhase: IPickerTerms;
  subCategory: IPickerTerms;
  agencies: IPickerTerms;
  documentStatus: IPickerTerms;
  byWhom: IPickerTerms;
  trades: IPickerTerms;
  documentDate: Date;
  actionDate: Date;
  loading: boolean;
  loadingScripts: boolean;
  errors: any;
}
